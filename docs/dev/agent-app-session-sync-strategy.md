# Agent/App Session 同步策略

日期：2026-05-03

## 目标

Session 对话展示必须满足：

- App 打开 session 后能从 Agent 获取完整、稳定的当前消息投影。
- App 正在观看 session 时，本 Agent 进程内产生的新消息能实时显示。
- WebSocket 断线、重连、乱序、重复事件不会导致消息丢失或重复合并。
- 不使用后台轮询同步 session history，避免持续浪费 Codex app-server 和 Agent 资源。

## 事实来源

Session 内容的事实来源是 provider。

对 Codex 来说，事实来源是 app-server 的 thread turns/items。Agent 不把 WebSocket delta 当作最终消息内容，也不让 App 直接合并 delta 成最终展示。

Agent 保存的是 provider history 的本地投影：

- `session_items`：当前可展示 item snapshot。
- `session_item_changes`：按 revision 递增的 upsert/delete 变更日志。
- `session_item_sync_state`：每个 session 的当前 revision 和最近 reconcile 状态。

App 保存的是展示缓存：

- Drift `session_item_entries` 存当前展示 item。
- Drift `sync_state_entries(scope=session_items)` 存 App 已同步到的 Agent item revision。

## HTTP 同步接口

Agent 提供两个权威读取接口：

```text
GET /api/v1/sessions/:id/items/snapshot
GET /api/v1/sessions/:id/items/changes?after_revision=N&limit=500&reconcile=false
```

`snapshot` 返回完整当前投影：

```json
{
  "session_id": "s1",
  "revision": 12,
  "items": []
}
```

`changes` 返回 revision 之后的变更：

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

`snapshot` 总是先向 provider 做一次全量 reconcile，然后返回当前投影。

`changes` 默认只读取 Agent 本地 projection change log，不访问 provider。App 在打开 session、前台恢复、显式同步等需要校准 provider history 的路径传 `reconcile=true`；实时 `session.items.changed` 路径传 `reconcile=false`，只拉 Agent 已经写入的本地 revision changes。

如果 App 的 `after_revision` 早于 Agent 保留的 change log，Agent 返回 `reset_required=true`，App 必须丢弃本地该 session 的非 pending 展示 item，重新拉 snapshot。

旧的 `GET /api/v1/sessions/:id/items` 只作为 snapshot wrapper 使用，App 主同步路径使用 snapshot/changes。

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

流式 delta 类事件只作为低延迟 UI 提示，不触发 Agent projection 写入，也不触发 provider reconcile，例如：

- `session.message_delta`
- `session.plan_delta`
- `session.reasoning_summary_delta`
- `session.reasoning_text_delta`
- `session.command_output_delta`
- `session.file_change_output_delta`

App 收到 `session.items.changed` 后调用 `refreshItems(sessionId, reconcile: false)`：

- 本地 revision 为 0：拉 snapshot。
- 本地 revision > 0：拉 changes，本次 changes 不触发 provider reconcile。
- changes 要求 reset：拉 snapshot。

App 收到 item projection hint event 时不调用 `refreshItems`。这些事件只用于临时实时展示或状态更新；持久展示由 `session.items.changed` 对应的 revision changes 或下一次全量 snapshot 校准。

WS replay cursor 对 item 同步不再承担可靠性职责。App 订阅 session 时发送 `items:<revision>`，Agent 只返回 `session.replay_complete`，不会 replay 旧 WS buffer 作为 item 来源。

## App 同步流程

### 打开 Session

1. ChatPage 创建 repository 并 watch Drift items。
2. SyncEngine `subscribeSession(sessionId)`。
3. SyncEngine 先发送 WS subscribe，同时进入 catch-up gate。
4. catch-up 调用 `SessionRepository.refreshItems(sessionId, reconcile: true)`。
5. refresh 写入 Drift。
6. ChatPage 由 Drift watch 自动刷新 UI。
7. catch-up 期间到达的 WS 事件先进入 buffer。catch-up 后：
   - 如果 revision 已推进，丢弃已被 HTTP 同步覆盖的 item hint。
   - 如果 revision 未推进，delta hint 只派发给 UI，不触发 HTTP refresh。

### 前台恢复

App 回到前台时，SyncEngine 对已订阅 session 重新执行 catch-up。这样可以覆盖后台期间断线或系统暂停造成的 missed event。

### 手动刷新

右上角刷新强制执行 snapshot，同步 provider 当前全量投影。

## Agent 触发 reconcile 的时机

允许的触发源：

- App 调用 snapshot/changes/items HTTP 接口。
- App 调用 changes 且显式传 `reconcile=true`。
- 本 Agent 进程内 provider runtime event 无法局部处理且必须兜底时，例如 turn failed。
- 创建 session 后的一次初始 reconcile。

不允许的触发源：

- 因 WebSocket subscribe 而启动后台定时 reconcile。
- 因 session active 而固定周期读取 provider history。

也就是说，Agent 不轮询 provider history。没有事件或 App 请求时，Agent 不主动访问 Codex thread history。

本 Agent 进程内 provider runtime event 到达时的默认处理方式：

- `item/completed`、agent message、command completed、file change、file read、mcp completed 等完整 item payload：局部 upsert projection，不访问 provider。
- plan/diff/reasoning 等没有稳定 provider item id 但带 turn id 的完整更新：使用 `turn_id + kind` 生成稳定 item id 后局部 upsert。
- message/command/reasoning/file delta：只通过 WS 传给 App，不写 projection，不访问 provider。

## 外部端推进 Session 的边界

如果同一个 Codex thread 在其他端被推进，而当前 Agent 没有收到 provider 主动通知，则 Agent 不会实时知道这件事。此时 App 的一致性由主动同步保证：

- 打开 session 会同步。
- 前台恢复会同步。
- 手动刷新会同步。
- 任何调用 snapshot 或 `changes?reconcile=true` 的页面都会同步。

若未来需要“外部端推进后 App 也实时出现”，必须接入 provider 提供的主动通知或订阅能力，例如 Codex app-server 能对已订阅 thread 推送外部更新事件。不能通过 Agent 自己定时扫描实现，因为那会重新引入后台轮询成本。

## 去重与可靠性规则

- App 本地只以 `session_items` revision 判断消息内容进度。
- WS `ws_cursor/ws_epoch` 只用于运行时事件调试和非 item 事件，不用于 item 可靠同步。
- App 在同步期间缓存 WS 事件，避免“先应用实时事件，后写入旧 snapshot”造成倒退。
- Agent projection 按 item id upsert/delete；provider snapshot 缺失的旧 item 会生成 delete revision。
- Runtime event 局部 upsert 不删除旧 item；删除只来自全量 snapshot reconcile。
- 实时 `session.items.changed` 只拉本地 change log，不触发 provider history 读取。
- Codex item 时间和排序必须稳定，不能使用 `time.Now()` 作为缺省值，否则每次 reconcile 都会产生虚假 revision。

## 性能原则

- 常规实时显示依赖 provider runtime event，不读完整 history。
- HTTP reconcile 只在用户可见或用户触发路径执行。
- 无变化的 snapshot/changes 日志使用 Debug。
- 只有实际产生 projection changes 时使用 Info。
