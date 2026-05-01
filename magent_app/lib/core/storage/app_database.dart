import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class ProjectEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get path => text()();
  TextColumn get defaultProvider => text().named('default_provider')();
  IntColumn get revision => integer().nullable()();
  TextColumn get dataJson => text().named('data_json')();
  DateTimeColumn get createdAt => dateTime().named('created_at').nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => {agentId, id};
}

class ProviderEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get name => text()();
  TextColumn get status => text()();
  TextColumn get version => text().nullable()();
  TextColumn get runMode => text().named('run_mode').nullable()();
  TextColumn get capabilitiesJson => text().named('capabilities_json')();
  TextColumn get configJson => text().named('config_json')();
  TextColumn get configSchemaJson => text().named('config_schema_json')();
  TextColumn get dataJson => text().named('data_json')();
  IntColumn get revision => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {agentId, name};
}

class SessionEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get id => text()();
  TextColumn get providerId => text().named('provider_id')();
  TextColumn get threadId => text().named('thread_id').nullable()();
  TextColumn get projectId => text().named('project_id')();
  TextColumn get purpose => text().nullable()();
  TextColumn get workdir => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('stopped'))();
  TextColumn get model => text().nullable()();
  TextColumn get effort => text().nullable()();
  TextColumn get approvalPolicy => text().named('approval_policy').nullable()();
  TextColumn get sandboxMode => text().named('sandbox_mode').nullable()();
  TextColumn get providerCursor => text().named('provider_cursor').nullable()();
  IntColumn get listRevision => integer().named('list_revision').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => {agentId, id};
}

class SessionEventEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get sessionId => text().named('session_id')();
  TextColumn get providerCursor => text().named('provider_cursor').nullable()();
  TextColumn get type => text()();
  TextColumn get itemId => text().named('item_id').nullable()();
  TextColumn get turnId => text().named('turn_id').nullable()();
  TextColumn get data => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}

class SessionItemEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get sessionId => text().named('session_id')();
  TextColumn get itemId => text().named('item_id')();
  TextColumn get turnId => text().named('turn_id').nullable()();
  TextColumn get type => text()();
  TextColumn get status => text().nullable()();
  TextColumn get role => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get content => text().withDefault(const Constant('{}'))();
  TextColumn get providerCursor => text().named('provider_cursor').nullable()();
  IntColumn get revision => integer().nullable()();
  IntColumn get itemIndex =>
      integer().named('item_index').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {agentId, sessionId, itemId};
}

class PendingApprovalEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get approvalId => text().named('approval_id')();
  TextColumn get sessionId => text().named('session_id')();
  TextColumn get itemId => text().named('item_id').nullable()();
  TextColumn get type => text()();
  TextColumn get requestJson => text().named('request_json')();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get resolvedAt => dateTime().named('resolved_at').nullable()();

  @override
  Set<Column> get primaryKey => {agentId, approvalId};
}

class SyncStateEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get scope => text()();
  TextColumn get key => text()();
  TextColumn get cursor => text().nullable()();
  TextColumn get hash => text().nullable()();
  IntColumn get revision => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {agentId, scope, key};
}

class GitSummaryEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get projectId => text().named('project_id')();
  IntColumn get version => integer()();
  TextColumn get dataJson => text().named('data_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {agentId, projectId};
}

class GitChangesEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get projectId => text().named('project_id')();
  IntColumn get version => integer()();
  TextColumn get filesJson => text().named('files_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {agentId, projectId};
}

class DirCacheEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get projectId => text().named('project_id')();
  TextColumn get path => text()();
  TextColumn get hash => text()();
  TextColumn get itemsJson => text().named('items_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {agentId, projectId, path};
}

class FileCacheEntries extends Table {
  TextColumn get agentId => text().named('agent_id')();
  TextColumn get projectId => text().named('project_id')();
  TextColumn get path => text()();
  TextColumn get rangeKey => text().named('range_key')();
  TextColumn get hash => text()();
  TextColumn get encoding => text().nullable()();
  TextColumn get content => text()();
  IntColumn get size => integer().nullable()();
  IntColumn get totalLines => integer().named('total_lines').nullable()();
  IntColumn get offset => integer().nullable()();
  IntColumn get limit => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {agentId, projectId, path, rangeKey};
}

class CacheBucketStats {
  final int entries;
  final int bytes;

  const CacheBucketStats({required this.entries, required this.bytes});
}

@DriftDatabase(
  tables: [
    ProjectEntries,
    ProviderEntries,
    SessionEntries,
    SessionEventEntries,
    SessionItemEntries,
    PendingApprovalEntries,
    SyncStateEntries,
    GitSummaryEntries,
    GitChangesEntries,
    DirCacheEntries,
    FileCacheEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      await customStatement('DROP TABLE IF EXISTS session_entries');
      await customStatement('DROP TABLE IF EXISTS project_entries');
      await customStatement('DROP TABLE IF EXISTS provider_entries');
      await customStatement('DROP TABLE IF EXISTS session_event_entries');
      await customStatement('DROP TABLE IF EXISTS session_item_entries');
      await customStatement('DROP TABLE IF EXISTS pending_approval_entries');
      await customStatement('DROP TABLE IF EXISTS sync_state_entries');
      await customStatement('DROP TABLE IF EXISTS git_summary_entries');
      await customStatement('DROP TABLE IF EXISTS git_changes_entries');
      await customStatement('DROP TABLE IF EXISTS dir_cache_entries');
      await customStatement('DROP TABLE IF EXISTS file_cache_entries');
      await m.createAll();
    },
  );

  // --- Project/provider control-plane cache ---

  Future<List<ProjectEntry>> getProjects(String agentId) {
    return (select(projectEntries)
          ..where((t) => t.agentId.equals(agentId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<ProjectEntry>> watchProjects(String agentId) {
    return (select(projectEntries)
          ..where((t) => t.agentId.equals(agentId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<ProjectEntry?> getProjectEntry(String agentId, String id) {
    return (select(projectEntries)
          ..where((t) => t.agentId.equals(agentId) & t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertProject(ProjectEntriesCompanion entry) {
    return into(projectEntries).insertOnConflictUpdate(entry);
  }

  Future<void> replaceProjects(
    String agentId,
    List<ProjectEntriesCompanion> entries,
  ) async {
    await transaction(() async {
      await (delete(
        projectEntries,
      )..where((t) => t.agentId.equals(agentId))).go();
      if (entries.isNotEmpty) {
        await batch((batch) {
          batch.insertAllOnConflictUpdate(projectEntries, entries);
        });
      }
    });
  }

  Future<void> removeProjectEntry(String agentId, String id) {
    return (delete(
      projectEntries,
    )..where((t) => t.agentId.equals(agentId) & t.id.equals(id))).go();
  }

  Future<List<ProviderEntry>> getProviders(String agentId) {
    return (select(providerEntries)
          ..where((t) => t.agentId.equals(agentId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Stream<List<ProviderEntry>> watchProviders(String agentId) {
    return (select(providerEntries)
          ..where((t) => t.agentId.equals(agentId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<ProviderEntry?> getProviderEntry(String agentId, String name) {
    return (select(providerEntries)
          ..where((t) => t.agentId.equals(agentId) & t.name.equals(name)))
        .getSingleOrNull();
  }

  Future<void> replaceProviders(
    String agentId,
    List<ProviderEntriesCompanion> entries,
  ) async {
    await transaction(() async {
      await (delete(
        providerEntries,
      )..where((t) => t.agentId.equals(agentId))).go();
      if (entries.isNotEmpty) {
        await batch((batch) {
          batch.insertAllOnConflictUpdate(providerEntries, entries);
        });
      }
    });
  }

  Future<String?> getSyncHash(String agentId, String scope, String key) async {
    final row =
        await (select(syncStateEntries)..where(
              (t) =>
                  t.agentId.equals(agentId) &
                  t.scope.equals(scope) &
                  t.key.equals(key),
            ))
            .getSingleOrNull();
    return row?.hash;
  }

  Future<void> setSyncState(
    String agentId,
    String scope,
    String key, {
    String? cursor,
    String? hash,
    int? revision,
  }) {
    return into(syncStateEntries).insertOnConflictUpdate(
      SyncStateEntriesCompanion(
        agentId: Value(agentId),
        scope: Value(scope),
        key: Value(key),
        cursor: Value(cursor),
        hash: Value(hash),
        revision: Value(revision),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<CacheBucketStats> getGitCacheStats(String agentId) {
    return _cacheStats(
      '''
      SELECT SUM(entry_count) AS entry_count, SUM(byte_count) AS byte_count
      FROM (
        SELECT COUNT(*) AS entry_count, COALESCE(SUM(LENGTH(data_json)), 0) AS byte_count
        FROM git_summary_entries
        WHERE agent_id = ?
        UNION ALL
        SELECT COUNT(*) AS entry_count, COALESCE(SUM(LENGTH(files_json)), 0) AS byte_count
        FROM git_changes_entries
        WHERE agent_id = ?
      )
      ''',
      [Variable.withString(agentId), Variable.withString(agentId)],
    );
  }

  Future<CacheBucketStats> getFileCacheStats(String agentId) {
    return _cacheStats(
      '''
      SELECT SUM(entry_count) AS entry_count, SUM(byte_count) AS byte_count
      FROM (
        SELECT COUNT(*) AS entry_count, COALESCE(SUM(LENGTH(items_json)), 0) AS byte_count
        FROM dir_cache_entries
        WHERE agent_id = ?
        UNION ALL
        SELECT COUNT(*) AS entry_count, COALESCE(SUM(LENGTH(content)), 0) AS byte_count
        FROM file_cache_entries
        WHERE agent_id = ?
      )
      ''',
      [Variable.withString(agentId), Variable.withString(agentId)],
    );
  }

  Future<CacheBucketStats> getSessionCacheStats(String agentId) {
    return _cacheStats(
      '''
      SELECT SUM(entry_count) AS entry_count, SUM(byte_count) AS byte_count
      FROM (
        SELECT COUNT(*) AS entry_count, COALESCE(SUM(LENGTH(data)), 0) AS byte_count
        FROM session_event_entries
        WHERE agent_id = ?
        UNION ALL
        SELECT COUNT(*) AS entry_count, COALESCE(SUM(LENGTH(content)), 0) AS byte_count
        FROM session_item_entries
        WHERE agent_id = ?
      )
      ''',
      [Variable.withString(agentId), Variable.withString(agentId)],
    );
  }

  Future<void> clearGitDisplayCache(String agentId) async {
    await (delete(
      gitSummaryEntries,
    )..where((t) => t.agentId.equals(agentId))).go();
    await (delete(
      gitChangesEntries,
    )..where((t) => t.agentId.equals(agentId))).go();
  }

  Future<void> clearFileDisplayCache(String agentId) async {
    await (delete(
      dirCacheEntries,
    )..where((t) => t.agentId.equals(agentId))).go();
    await (delete(
      fileCacheEntries,
    )..where((t) => t.agentId.equals(agentId))).go();
  }

  Future<void> clearSessionDisplayCache(String agentId) async {
    await (delete(
      sessionEventEntries,
    )..where((t) => t.agentId.equals(agentId))).go();
    await (delete(
      sessionItemEntries,
    )..where((t) => t.agentId.equals(agentId))).go();
    await (delete(syncStateEntries)..where(
          (t) =>
              t.agentId.equals(agentId) &
              (t.scope.equals('session_events') |
                  t.scope.equals('session_items') |
                  t.scope.equals('session_ws')),
        ))
        .go();
  }

  Future<void> clearAllDisplayCaches(String agentId) async {
    await transaction(() async {
      await clearGitDisplayCache(agentId);
      await clearFileDisplayCache(agentId);
      await clearSessionDisplayCache(agentId);
    });
  }

  Future<CacheBucketStats> _cacheStats(
    String sql,
    List<Variable<Object>> variables,
  ) async {
    final row = await customSelect(sql, variables: variables).getSingle();
    return CacheBucketStats(
      entries: row.read<int?>('entry_count') ?? 0,
      bytes: row.read<int?>('byte_count') ?? 0,
    );
  }

  // --- Session operations ---

  Future<List<SessionEntry>> getSessionsByProject(
    String agentId,
    String projectId,
  ) {
    return (select(sessionEntries)
          ..where(
            (t) => t.agentId.equals(agentId) & t.projectId.equals(projectId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<SessionEntry>> watchSessionsByProject(
    String agentId,
    String projectId,
  ) {
    return (select(sessionEntries)
          ..where(
            (t) => t.agentId.equals(agentId) & t.projectId.equals(projectId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<SessionEntry?> getSession(String agentId, String id) {
    return (select(sessionEntries)
          ..where((t) => t.agentId.equals(agentId) & t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertOrUpdateSession(SessionEntriesCompanion entry) {
    return into(sessionEntries).insertOnConflictUpdate(entry);
  }

  Future<void> insertOrUpdateSessions(
    List<SessionEntriesCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(sessionEntries, entries);
    });
  }

  Future<void> deleteSession(String agentId, String id) {
    return (delete(
      sessionEntries,
    )..where((t) => t.agentId.equals(agentId) & t.id.equals(id))).go();
  }

  // --- Event operations ---

  Future<List<SessionEventEntry>> getEventsBySession(
    String agentId,
    String sessionId,
  ) {
    return (select(sessionEventEntries)
          ..where(
            (t) => t.agentId.equals(agentId) & t.sessionId.equals(sessionId),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<void> insertEvents(List<SessionEventEntriesCompanion> entries) async {
    await batch((batch) {
      batch.insertAll(sessionEventEntries, entries);
    });
  }

  Future<void> deleteEventsBySession(String agentId, String sessionId) {
    return (delete(sessionEventEntries)..where(
          (t) => t.agentId.equals(agentId) & t.sessionId.equals(sessionId),
        ))
        .go();
  }

  // --- Item operations ---

  Future<List<SessionItemEntry>> getItemsBySession(
    String agentId,
    String sessionId,
  ) async {
    final rows = await _itemsBySessionQuery(agentId, sessionId).get();
    return rows.reversed.toList(growable: false);
  }

  Stream<List<SessionItemEntry>> watchItemsBySession(
    String agentId,
    String sessionId,
  ) {
    return _itemsBySessionQuery(
      agentId,
      sessionId,
    ).watch().map((rows) => rows.reversed.toList(growable: false));
  }

  SimpleSelectStatement<$SessionItemEntriesTable, SessionItemEntry>
  _itemsBySessionQuery(String agentId, String sessionId) {
    return select(sessionItemEntries)
      ..where((t) => t.agentId.equals(agentId) & t.sessionId.equals(sessionId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.itemIndex),
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.itemId),
      ]);
  }

  Future<List<SessionItemEntry>> getRecentItemsBySession(
    String agentId,
    String sessionId,
    int limit,
  ) async {
    final rows = await (_itemsBySessionQuery(
      agentId,
      sessionId,
    )..limit(limit)).get();
    return rows.reversed.toList(growable: false);
  }

  Stream<List<SessionItemEntry>> watchRecentItemsBySession(
    String agentId,
    String sessionId,
    int limit,
  ) {
    return (_itemsBySessionQuery(agentId, sessionId)..limit(limit)).watch().map(
      (rows) => rows.reversed.toList(growable: false),
    );
  }

  Stream<int> watchItemCountBySession(String agentId, String sessionId) {
    return (selectOnly(sessionItemEntries)
          ..addColumns([sessionItemEntries.itemId.count()])
          ..where(
            sessionItemEntries.agentId.equals(agentId) &
                sessionItemEntries.sessionId.equals(sessionId),
          ))
        .watchSingle()
        .map((row) => row.read(sessionItemEntries.itemId.count()) ?? 0);
  }

  Future<SessionItemEntry?> getItem(
    String agentId,
    String sessionId,
    String itemId,
  ) {
    return (select(sessionItemEntries)..where(
          (t) =>
              t.agentId.equals(agentId) &
              t.sessionId.equals(sessionId) &
              t.itemId.equals(itemId),
        ))
        .getSingleOrNull();
  }

  Future<void> insertOrUpdateItem(SessionItemEntriesCompanion entry) {
    return into(sessionItemEntries).insertOnConflictUpdate(entry);
  }

  Future<void> deleteItem(String agentId, String sessionId, String itemId) {
    return (delete(sessionItemEntries)..where(
          (t) =>
              t.agentId.equals(agentId) &
              t.sessionId.equals(sessionId) &
              t.itemId.equals(itemId),
        ))
        .go();
  }

  Future<void> insertOrUpdateItems(
    List<SessionItemEntriesCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(sessionItemEntries, entries);
    });
  }

  Future<void> deleteItemsBySession(String agentId, String sessionId) {
    return (delete(sessionItemEntries)..where(
          (t) => t.agentId.equals(agentId) & t.sessionId.equals(sessionId),
        ))
        .go();
  }

  // --- Approval operations ---

  Future<void> upsertPendingApproval(PendingApprovalEntriesCompanion entry) {
    return into(pendingApprovalEntries).insertOnConflictUpdate(entry);
  }

  Future<void> resolvePendingApproval(
    String agentId,
    String approvalId,
    String status,
  ) {
    return (update(pendingApprovalEntries)..where(
          (t) => t.agentId.equals(agentId) & t.approvalId.equals(approvalId),
        ))
        .write(
          PendingApprovalEntriesCompanion(
            status: Value(status),
            resolvedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<String?> getSyncCursor(
    String agentId,
    String scope,
    String key,
  ) async {
    final row =
        await (select(syncStateEntries)..where(
              (t) =>
                  t.agentId.equals(agentId) &
                  t.scope.equals(scope) &
                  t.key.equals(key),
            ))
            .getSingleOrNull();
    return row?.cursor;
  }

  Future<void> setSyncCursor(
    String agentId,
    String scope,
    String key,
    String cursor,
  ) {
    return setSyncState(agentId, scope, key, cursor: cursor);
  }

  // --- Git cache operations ---

  Future<GitSummaryEntry?> getGitSummary(String agentId, String projectId) {
    return (select(gitSummaryEntries)..where(
          (t) => t.agentId.equals(agentId) & t.projectId.equals(projectId),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertGitSummary(GitSummaryEntriesCompanion entry) {
    return into(gitSummaryEntries).insertOnConflictUpdate(entry);
  }

  Future<GitChangesEntry?> getGitChanges(String agentId, String projectId) {
    return (select(gitChangesEntries)..where(
          (t) => t.agentId.equals(agentId) & t.projectId.equals(projectId),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertGitChanges(GitChangesEntriesCompanion entry) {
    return into(gitChangesEntries).insertOnConflictUpdate(entry);
  }

  Future<void> clearGitCache(String agentId, String projectId) async {
    await (delete(gitSummaryEntries)..where(
          (t) => t.agentId.equals(agentId) & t.projectId.equals(projectId),
        ))
        .go();
    await (delete(gitChangesEntries)..where(
          (t) => t.agentId.equals(agentId) & t.projectId.equals(projectId),
        ))
        .go();
  }

  // --- File cache operations ---

  Future<DirCacheEntry?> getDirCache(
    String agentId,
    String projectId,
    String path,
  ) {
    return (select(dirCacheEntries)..where(
          (t) =>
              t.agentId.equals(agentId) &
              t.projectId.equals(projectId) &
              t.path.equals(path),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertDirCache(DirCacheEntriesCompanion entry) {
    return into(dirCacheEntries).insertOnConflictUpdate(entry);
  }

  Future<FileCacheEntry?> getFileCache(
    String agentId,
    String projectId,
    String path,
    String rangeKey,
  ) {
    return (select(fileCacheEntries)..where(
          (t) =>
              t.agentId.equals(agentId) &
              t.projectId.equals(projectId) &
              t.path.equals(path) &
              t.rangeKey.equals(rangeKey),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertFileCache(FileCacheEntriesCompanion entry) {
    return into(fileCacheEntries).insertOnConflictUpdate(entry);
  }

  Future<void> clearFileCacheForPath(
    String agentId,
    String projectId,
    String path,
  ) {
    return (delete(fileCacheEntries)..where(
          (t) =>
              t.agentId.equals(agentId) &
              t.projectId.equals(projectId) &
              t.path.equals(path),
        ))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'magent.db'));
    return NativeDatabase.createInBackground(file);
  });
}
