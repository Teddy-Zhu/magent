package session

import (
	"context"
	"database/sql"
	"encoding/json"
	"sort"
	"sync"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/provider"
)

const defaultItemChangeLimit = 500

type ItemChangesPage struct {
	SessionID     string       `json:"session_id"`
	FromRevision  int64        `json:"from_revision"`
	ToRevision    int64        `json:"to_revision"`
	Changes       []ItemChange `json:"changes"`
	ResetRequired bool         `json:"reset_required"`
	HasMore       bool         `json:"has_more"`
}

type ItemChange struct {
	Revision int64                 `json:"revision"`
	Op       string                `json:"op"`
	ItemID   string                `json:"item_id"`
	Item     *provider.SessionItem `json:"item,omitempty"`
}

type itemProjectionStore struct {
	db *sql.DB
	mu sync.Mutex
}

func nullableString(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func newItemProjectionStore(store *SessionStore) *itemProjectionStore {
	return &itemProjectionStore{db: store.db.DB()}
}

func (s *itemProjectionStore) Changes(ctx context.Context, sessionID string, afterRevision int64, limit int) (*ItemChangesPage, error) {
	if limit <= 0 || limit > defaultItemChangeLimit {
		limit = defaultItemChangeLimit
	}
	currentRevision, err := s.revision(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	if afterRevision >= currentRevision {
		return &ItemChangesPage{
			SessionID:    sessionID,
			FromRevision: afterRevision,
			ToRevision:   currentRevision,
			Changes:      []ItemChange{},
		}, nil
	}

	var minRevision sql.NullInt64
	if err := s.db.QueryRowContext(ctx, `
		SELECT MIN(revision) FROM session_item_changes WHERE session_id = ?`, sessionID).Scan(&minRevision); err != nil {
		return nil, err
	}
	if !minRevision.Valid || minRevision.Int64 > afterRevision+1 {
		return &ItemChangesPage{
			SessionID:     sessionID,
			FromRevision:  afterRevision,
			ToRevision:    currentRevision,
			ResetRequired: true,
			Changes:       []ItemChange{},
		}, nil
	}

	rows, err := s.db.QueryContext(ctx, `
		SELECT revision, op, item_id, item_json
		FROM session_item_changes
		WHERE session_id = ? AND revision > ?
		ORDER BY revision ASC
		LIMIT ?`, sessionID, afterRevision, limit+1)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	changes := make([]ItemChange, 0, limit)
	hasMore := false
	toRevision := afterRevision
	for rows.Next() {
		if len(changes) >= limit {
			hasMore = true
			break
		}
		var change ItemChange
		var itemJSON sql.NullString
		if err := rows.Scan(&change.Revision, &change.Op, &change.ItemID, &itemJSON); err != nil {
			return nil, err
		}
		if itemJSON.Valid && itemJSON.String != "" {
			var item provider.SessionItem
			if err := json.Unmarshal([]byte(itemJSON.String), &item); err != nil {
				return nil, err
			}
			change.Item = &item
		}
		toRevision = change.Revision
		changes = append(changes, change)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return &ItemChangesPage{
		SessionID:    sessionID,
		FromRevision: afterRevision,
		ToRevision:   toRevision,
		Changes:      changes,
		HasMore:      hasMore,
	}, nil
}

func (s *itemProjectionStore) Upsert(ctx context.Context, sessionID string, item provider.SessionItem) (*ItemChangesPage, error) {
	return s.applyItems(ctx, sessionID, []provider.SessionItem{item})
}

func (s *itemProjectionStore) NextOrderKey(ctx context.Context, sessionID string) (int, error) {
	var maxOrder sql.NullInt64
	if err := s.db.QueryRowContext(ctx, `
		SELECT MAX(order_key) FROM session_items WHERE session_id = ?`, sessionID).Scan(&maxOrder); err != nil {
		return 0, err
	}
	if !maxOrder.Valid {
		return 0, nil
	}
	return int(maxOrder.Int64 + 1), nil
}

func (s *itemProjectionStore) ItemOrderKey(ctx context.Context, sessionID, itemID string) (int, bool, error) {
	var orderKey sql.NullInt64
	if err := s.db.QueryRowContext(ctx, `
		SELECT order_key FROM session_items
		WHERE session_id = ? AND item_id = ? AND deleted_at IS NULL`, sessionID, itemID).Scan(&orderKey); err != nil {
		if err == sql.ErrNoRows {
			return 0, false, nil
		}
		return 0, false, err
	}
	if !orderKey.Valid {
		return 0, false, nil
	}
	return int(orderKey.Int64), true, nil
}

func (s *itemProjectionStore) applyItems(ctx context.Context, sessionID string, incomingItems []provider.SessionItem) (*ItemChangesPage, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	sort.SliceStable(incomingItems, func(i, j int) bool {
		if incomingItems[i].Index != incomingItems[j].Index {
			return incomingItems[i].Index < incomingItems[j].Index
		}
		if !incomingItems[i].CreatedAt.Equal(incomingItems[j].CreatedAt) {
			return incomingItems[i].CreatedAt.Before(incomingItems[j].CreatedAt)
		}
		return incomingItems[i].ItemID < incomingItems[j].ItemID
	})

	currentRevision, err := s.revision(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	fromRevision := currentRevision
	existing, err := s.itemMap(ctx, sessionID)
	if err != nil {
		return nil, err
	}

	now := time.Now().Unix()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	changes := make([]ItemChange, 0)
	for _, incoming := range incomingItems {
		if incoming.ItemID == "" {
			continue
		}
		incoming.Type = provider.NormalizeItemType(incoming.Type)
		if incoming.CreatedAt.IsZero() {
			incoming.CreatedAt = time.Now()
		}
		if incoming.UpdatedAt.IsZero() {
			incoming.UpdatedAt = incoming.CreatedAt
		}
		previous, ok := existing[incoming.ItemID]
		if ok && sessionItemEqual(previous, incoming) {
			delete(existing, incoming.ItemID)
			continue
		}

		currentRevision++
		incoming.Revision = currentRevision
		itemJSON, err := json.Marshal(incoming)
		if err != nil {
			return nil, err
		}
		contentJSON, err := json.Marshal(incoming.Content)
		if err != nil {
			contentJSON = []byte(`{}`)
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO session_items (
				session_id, item_id, turn_id, order_key, revision, type, status, role, summary,
				content_json, provider_cursor, created_at, updated_at, deleted_at
			)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
			ON CONFLICT(session_id, item_id) DO UPDATE SET
				turn_id = excluded.turn_id,
				order_key = excluded.order_key,
				revision = excluded.revision,
				type = excluded.type,
				status = excluded.status,
				role = excluded.role,
				summary = excluded.summary,
				content_json = excluded.content_json,
				provider_cursor = excluded.provider_cursor,
				created_at = excluded.created_at,
				updated_at = excluded.updated_at,
				deleted_at = NULL`,
			sessionID, incoming.ItemID, nullableString(incoming.TurnID), incoming.Index, currentRevision,
			incoming.Type, nullableString(incoming.Status), nullableString(incoming.Role), nullableString(incoming.Summary),
			string(contentJSON), nullableString(incoming.Cursor), incoming.CreatedAt.Unix(), incoming.UpdatedAt.Unix()); err != nil {
			return nil, err
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO session_item_changes (session_id, revision, op, item_id, item_json, created_at)
			VALUES (?, ?, 'upsert', ?, ?, ?)`, sessionID, currentRevision, incoming.ItemID, string(itemJSON), now); err != nil {
			return nil, err
		}
		copied := incoming
		changes = append(changes, ItemChange{Revision: currentRevision, Op: "upsert", ItemID: incoming.ItemID, Item: &copied})
		delete(existing, incoming.ItemID)
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO session_item_sync_state (session_id, revision)
		VALUES (?, ?)
		ON CONFLICT(session_id) DO UPDATE SET revision = excluded.revision`,
		sessionID, currentRevision); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return &ItemChangesPage{
		SessionID:    sessionID,
		FromRevision: fromRevision,
		ToRevision:   currentRevision,
		Changes:      changes,
	}, nil
}

func (s *itemProjectionStore) revision(ctx context.Context, sessionID string) (int64, error) {
	var revision sql.NullInt64
	if err := s.db.QueryRowContext(ctx, `
		SELECT revision FROM session_item_sync_state WHERE session_id = ?`, sessionID).Scan(&revision); err != nil {
		if err == sql.ErrNoRows {
			return 0, nil
		}
		return 0, err
	}
	if !revision.Valid {
		return 0, nil
	}
	return revision.Int64, nil
}

func (s *itemProjectionStore) Items(ctx context.Context, sessionID string) ([]provider.SessionItem, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT item_id, turn_id, order_key, revision, type, status, role, summary, content_json, provider_cursor, created_at, updated_at
		FROM session_items
		WHERE session_id = ? AND deleted_at IS NULL
		ORDER BY order_key ASC, created_at ASC, item_id ASC`, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []provider.SessionItem
	for rows.Next() {
		item, err := scanProjectionItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *itemProjectionStore) itemMap(ctx context.Context, sessionID string) (map[string]provider.SessionItem, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT item_id, turn_id, order_key, revision, type, status, role, summary, content_json, provider_cursor, created_at, updated_at
		FROM session_items
		WHERE session_id = ? AND deleted_at IS NULL`, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := map[string]provider.SessionItem{}
	for rows.Next() {
		item, err := scanProjectionItem(rows)
		if err != nil {
			return nil, err
		}
		items[item.ItemID] = item
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

type itemScanner interface {
	Scan(dest ...any) error
}

func scanProjectionItem(row itemScanner) (provider.SessionItem, error) {
	var item provider.SessionItem
	var turnID, status, role, summary, providerCursor sql.NullString
	var contentJSON string
	var createdAt, updatedAt int64
	if err := row.Scan(
		&item.ItemID, &turnID, &item.Index, &item.Revision, &item.Type, &status, &role, &summary,
		&contentJSON, &providerCursor, &createdAt, &updatedAt,
	); err != nil {
		return item, err
	}
	item.TurnID = turnID.String
	item.Status = status.String
	item.Role = role.String
	item.Summary = summary.String
	item.Cursor = providerCursor.String
	item.CreatedAt = time.Unix(createdAt, 0)
	item.UpdatedAt = time.Unix(updatedAt, 0)
	var content any
	if err := json.Unmarshal([]byte(contentJSON), &content); err != nil {
		content = map[string]any{}
	}
	item.Content = content
	return item, nil
}

func sessionItemEqual(a, b provider.SessionItem) bool {
	a.Revision = 0
	b.Revision = 0
	a.Type = provider.NormalizeItemType(a.Type)
	b.Type = provider.NormalizeItemType(b.Type)
	return a.Cursor == b.Cursor &&
		a.ItemID == b.ItemID &&
		a.TurnID == b.TurnID &&
		a.Index == b.Index &&
		a.Type == b.Type &&
		a.Status == b.Status &&
		a.Role == b.Role &&
		a.Summary == b.Summary &&
		a.CreatedAt.Unix() == b.CreatedAt.Unix() &&
		a.UpdatedAt.Unix() == b.UpdatedAt.Unix() &&
		jsonStableEqual(a.Content, b.Content)
}

func jsonStableEqual(a, b any) bool {
	aj, err := json.Marshal(a)
	if err != nil {
		return false
	}
	bj, err := json.Marshal(b)
	if err != nil {
		return false
	}
	return string(aj) == string(bj)
}
