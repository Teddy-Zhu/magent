# Agent/App Session 同步策略

日期：2026-05-06

## 目标

Session 对话展示必须满足：

- App 打开 session 只拉最新消息窗口，用户回看时再分页拉旧消息。
- App 正在观看 session 时，本 Agent 进程内产生的新消息能实时显示。
- WebSocket 断线、重连、乱序、重复事件不会导致消息丢失或重复合并。
- 不做完整 history sync，不后台轮询 provider history。

## 事实来源

Session 内容的事实来源是 provider。对 Codex 来说，事实来源是 app-server 的 thread turns/items。

Agent 保存的是本进程运行期产生的 item 投影：

- `session_items`：完整 runtime item event 的局部 upsert 投影。
- `session_item_changes`：按 revision 递增的 upsert 变更日志。
- `session_item_sync_state`：每个 session 的当前运行期 revision。

App 保存的是窗口展示缓存：

- Drift `session_item_entries` 存已加载窗口和运行期 item。
- Drift `sync_state_entries(scope=session_items)` 存 App 已同步到的 Agent runtime revision。
- Drift `sync_state_entries(scope=session_items_older)` 存继续加载更早窗口的 provider cursor。

## HTTP 同步接口

Agent 提供两个读取接口：

```text
GET /api/v1/sessions/:id/items?cursor=&limit=80
GET /api/v1/sessions/:id/items/changes?after_revision=N&limit=500
```

`items` 返回 provider-backed 历史窗口。空 cursor 返回最新窗口；返回的 cursor 用于继续加载更早窗口：

```json
{
  "session_id": "s1",
  "cursor": "older-page-cursor",
  "has_more": true,
  "items": []
}
```

`changes` 返回 Agent runtime revision 之后的变更：

```json
{
  "session_id": "s1",
  "from_revision": 12,
  "to_revision": 15,
  "reset_required": false,
  "has_more": false,
  "changes": []
}
```

`changes` 只读取 Agent 本地 change log，不访问 provider。

如果 App 的 `after_revision` 早于 Agent 保留的 change log，Agent 返回 `reset_required=true`，App 丢弃该 session 的非 pending 展示 item，重新拉最新窗口。

## WebSocket 语义

WebSocket 不作为消息内容事实来源，只作为低延迟提示通道。

Agent 仍会广播 provider runtime event：

```json
{
  "type": "session.event",
  "session_id": "s1",
  "event_type": "session.message_delta",
  "data": {}
}
```

对会影响 item projection 的完整 item 事件，Agent 优先直接把 event payload 转成 `session_items` 局部 upsert，不读取 provider history。若 upsert 产生新 revision，则广播：

```json
{
  "type": "session.items.changed",
  "session_id": "s1",
  "from_revision": 12,
  "to_revision": 15
}
```

流式 delta 类事件只作为低延迟 UI 提示，不触发 Agent projection 写入，也不触发 provider history sync，例如：

- `session.message_delta`
- `session.plan_delta`
- `session.reasoning_summary_delta`
- `session.reasoning_text_delta`
- `session.command_output_delta`
- `session.file_change_output_delta`

App 收到 `session.items.changed` 后调用 `refreshItems(sessionId)`：

- 本地 revision 为 0：拉最新窗口。
- 本地 revision > 0：拉 changes，本次 changes 不触发 provider history sync。
- changes 要求 reset：重置窗口缓存并拉最新窗口。

App 收到 item projection hint event 时不调用 `refreshItems`。这些事件只用于临时实时展示或状态更新；持久展示由 `session.items.changed` 对应的 revision changes 或下一次窗口读取校准。

WS replay cursor 对 item 同步不再承担可靠性职责。App 订阅 session 时发送 `items:<revision>`，Agent 只返回 `session.replay_complete`，不会 replay 旧 WS buffer 作为 item 来源。

## App 同步流程

### 打开 Session

1. ChatPage 创建 repository 并 watch Drift items。
2. SyncEngine `subscribeSession(sessionId)`。
3. SyncEngine 先发送 WS subscribe，同时进入 catch-up gate。
4. ChatPage 调用 `SessionRepository.loadLatestItemsPage(sessionId)` 拉最新窗口。
5. SyncEngine catch-up 只拉 runtime changes；本地 revision 为 0 时也不会拉 provider history 窗口。
6. ChatPage 由 Drift watch 自动刷新 UI。
7. catch-up 期间到达的 WS 事件先进入 buffer。catch-up 后：
   - 如果 revision 已推进，丢弃已被 HTTP 同步覆盖的 item hint。
   - 如果 revision 未推进，delta hint 只派发给 UI，不触发 HTTP refresh。

### 前台恢复

App 回到前台时，SyncEngine 对已订阅 session 重新执行 runtime catch-up。历史窗口仍由用户可见的 ChatPage 读取触发。

### 手动刷新

右上角刷新重置当前窗口缓存并重新拉最新窗口。

## Agent 访问 provider history 的时机

允许的触发源：

- App 调用 `/sessions/:id/items?cursor=&limit=` 获取用户可见窗口。
- 用户继续回看旧消息时调用同一接口加载更早窗口。

不允许的触发源：

- WebSocket subscribe。
- 前台恢复的 catch-up。
- 创建 session 后的后台 history sync。
- runtime event 无法局部处理时的兜底扫描。

Agent 不轮询 provider history。没有用户可见的分页请求时，Agent 不主动访问 Codex thread history。

本 Agent 进程内 provider runtime event 到达时的默认处理方式：

- `item/completed`、agent message、command completed、file change、file read、mcp completed 等完整 item payload：局部 upsert projection，不访问 provider。
- plan/diff/reasoning 等没有稳定 provider item id 但带 turn id 的完整更新：使用 `turn_id + kind` 生成稳定 item id 后局部 upsert。
- message/command/reasoning/file delta：只通过 WS 传给 App，不写 projection，不访问 provider。

## 外部端推进 Session 的边界

如果同一个 Codex thread 在其他端被推进，而当前 Agent 没有收到 provider 主动通知，则 Agent 不会实时知道这件事。此时 App 的一致性由窗口读取保证：

- 打开 session 会读取最新窗口。
- 手动刷新会重新读取最新窗口。
- 用户回看会按 cursor 读取旧窗口。

若未来需要“外部端推进后 App 也实时出现”，必须接入 provider 提供的主动通知或订阅能力，例如 Codex app-server 能对已订阅 thread 推送外部更新事件。不能通过 Agent 自己定时扫描实现，因为那会重新引入后台轮询成本。

## 去重与可靠性规则

- App 本地以 `session_items` revision 判断 runtime changes 进度；历史窗口缓存不代表完整副本。
- WS `ws_cursor/ws_epoch` 只用于运行时事件调试和非 item 事件，不用于 item 可靠同步。
- App 在同步期间缓存 WS 事件，避免乱序事件覆盖更新后的本地状态。
- Agent projection 按 item id upsert；窗口缓存重置由 App 本地执行。
- Runtime event 局部 upsert 不删除旧 item。
- 实时 `session.items.changed` 只拉本地 change log，不触发 provider history 读取。
- Codex item 时间和排序必须稳定，不能使用 `time.Now()` 作为缺省值，否则重复窗口读取会产生虚假变更。

## 性能原则

- 常规实时显示依赖 provider runtime event，不读完整 history。
- HTTP provider history 读取只在用户可见窗口执行。
- 无变化的 changes 日志使用 Debug。
- 只有实际产生 projection changes 时使用 Info。
