# Phase 7：高级功能（2 周）

## 目标

Push 通知、多 Agent 管理、多设备同步、加密备份、快捷 Prompt 模板等高级功能。

## 前置条件

Phase 1-5 完成。

---

## 一、Push 通知

### 1.1 通知场景

| 场景 | 触发时机 | 优先级 |
|---|---|---|
| 会话完成 | turn.completed | 普通 |
| 会话失败 | turn.failed | 高 |
| 审批请求 | approval_request | 高（阻塞） |
| Git 变化 | git.changed（debounce 后） | 低 |

### 1.2 实现方案

使用 Firebase Cloud Messaging (FCM) 或 APNs：

```go
// internal/notify/notifier.go

type Notifier struct {
    fcmClient *fcm.Client
    tokens    map[string][]string // agentName → device tokens
}

func (n *Notifier) NotifyDevice(deviceToken string, msg Notification) error {
    // 发送到单个设备
}

func (n *Notifier) NotifyAgent(agentName string, msg Notification) error {
    // 发送到 Agent 关联的所有设备
}
```

**第一版简化**：不集成 FCM，仅通过 WebSocket 长连接保持通知。手机 App 在后台时使用本地通知。

---

## 二、多 Agent 管理

### 2.1 数据模型

```go
type Agent struct {
    ID         string    `json:"id"`
    Name       string    `json:"name"`
    BaseURL    string    `json:"base_url"`
    Token      string    `json:"-"` // 不返回给客户端
    Status     string    `json:"status"` // "online" | "offline"
    Version    string    `json:"version"`
    LastSeen   time.Time `json:"last_seen"`
    CreatedAt  time.Time `json:"created_at"`
}
```

### 2.2 Flutter 多 Agent 切换

```dart
// app/providers/agent_provider.dart

class AgentProvider extends StateNotifier<AgentState> {
  // 支持多个 Agent
  // 顶部下拉切换当前 Agent
  // 每个 Agent 独立的项目/会话列表
  // 断线 Agent 显示为灰色
}
```

---

## 三、多设备同步

### 3.1 问题

多个手机同时连接同一个 Agent，需要同步状态。

### 3.2 方案

利用 WebSocket 广播：

```
设备 A 发送消息 → Agent → 广播到所有设备
                    ↓
              设备 B 也收到
```

需要同步的状态：
- 会话事件（已通过 WebSocket 广播）
- 审批决策（一台设备决策后，其他设备收到 resolved 通知）
- Git 状态变化

**不需要同步**：
- 本地 UI 状态（滚动位置、展开折叠）
- 本地缓存

---

## 四、会话导出

### 4.1 导出格式

```go
// POST /api/sessions/:id/export
func (h *SessionHandler) Export(c *gin.Context) {
    format := c.Query("format") // "markdown" | "json"

    session, _ := h.manager.GetSession(c.Param("id"))
    events, _ := h.manager.GetEventsAfterSeq(c.Param("id"), 0, 10000)

    switch format {
    case "markdown":
        md := exportToMarkdown(session, events)
        c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s.md", session.Title))
        c.Data(200, "text/markdown", []byte(md))
    case "json":
        c.JSON(200, map[string]any{"session": session, "events": events})
    }
}
```

---

## 五、快捷 Prompt 模板

### 5.1 模板存储

```go
type PromptTemplate struct {
    ID          string `json:"id"`
    Name        string `json:"name"`
    Description string `json:"description"`
    Template    string `json:"template"` // 支持 {{variable}} 占位符
    Category    string `json:"category"`
}
```

### 5.2 内置模板

```yaml
templates:
  - name: "修复 Bug"
    template: "请分析并修复以下 bug：{{description}}"
    category: "debug"

  - name: "代码审查"
    template: "请审查 {{file}} 的代码，关注：安全性、性能、可读性"
    category: "review"

  - name: "添加测试"
    template: "请为 {{file}} 添加单元测试，覆盖主要功能路径"
    category: "test"

  - name: "重构"
    template: "请重构 {{file}}，目标：{{goal}}"
    category: "refactor"

  - name: "解释代码"
    template: "请解释 {{file}} 中 {{function}} 函数的逻辑"
    category: "learn"
```

---

## 六、主题系统

```dart
// app/theme.dart

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: Colors.blue,
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blue,
      useMaterial3: true,
    );
  }

  // 代码主题（用于语法高亮）
  static Map<String, TextStyle> codeTheme(bool isDark) {
    return isDark ? atomOneDarkTheme : atomOneLightTheme;
  }
}
```

---

## 七、实施步骤

| 天 | 任务 |
|---|---|
| D1-2 | Push 通知（WebSocket 保持 + 本地通知） |
| D3-4 | 多 Agent 管理（Flutter 切换 + 状态隔离） |
| D5-6 | 多设备同步（WebSocket 广播 + 审决策同步） |
| D7-8 | 会话导出（Markdown + JSON） |
| D9-10 | 快捷 Prompt 模板（CRUD + 内置模板） |
| D11-12 | 主题系统 + UI 打磨 |
| D13-14 | 集成测试 + Bug 修复 |

---

## 八、验收标准

1. 手机 App 后台时，收到会话完成/审批请求的本地通知
2. 可管理多个 Agent，切换后显示对应数据
3. 两台手机同时连接，审批决策同步
4. 会话可导出为 Markdown
5. 快捷 Prompt 模板可用，支持自定义
6. 亮/暗主题切换正常
