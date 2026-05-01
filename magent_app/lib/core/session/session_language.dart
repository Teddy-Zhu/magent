class SessionStatuses {
  static const running = 'running';
  static const stopped = 'stopped';
  static const completed = 'completed';
  static const failed = 'failed';
  static const lost = 'lost';

  const SessionStatuses._();

  static String? normalize(dynamic status) {
    final raw = status is Map
        ? status['type']?.toString() ?? status['status']?.toString()
        : status?.toString();
    switch (raw) {
      case 'idle':
      case 'active':
      case 'running':
      case 'inProgress':
        return running;
      case 'completed':
      case 'succeeded':
      case 'exited':
        return completed;
      case 'systemError':
      case 'failed':
      case 'error':
        return failed;
      case 'notLoaded':
      case 'not_loaded':
      case 'stopped':
      case 'closed':
        return stopped;
      case 'lost':
        return lost;
      case null:
      case '':
        return null;
      default:
        return raw;
    }
  }

  static String normalizeOrStopped(dynamic status) {
    return normalize(status) ?? stopped;
  }

  static bool isRunning(dynamic status) => normalize(status) == running;

  static bool canResume(dynamic status) {
    final value = normalize(status);
    return value == stopped || value == failed;
  }

  static bool isEnded(dynamic status) {
    final value = normalize(status);
    return value == completed || value == lost;
  }

  static String label(dynamic status) {
    switch (normalize(status)) {
      case running:
        return '运行中';
      case completed:
        return '已完成';
      case stopped:
        return '已停止';
      case failed:
        return '失败';
      case lost:
        return '已丢失';
      case null:
        return '未知';
      default:
        return normalize(status)!;
    }
  }
}

class SessionPurposes {
  static const aiCommit = 'ai_commit';

  const SessionPurposes._();
}

class SessionApprovalPolicies {
  static const onRequest = 'on-request';
  static const onFailure = 'on-failure';
  static const never = 'never';
  static const untrusted = 'untrusted';
  static const granular = 'granular';

  const SessionApprovalPolicies._();

  static String? normalize(dynamic policy) {
    switch (policy?.toString()) {
      case 'on-request':
      case 'onRequest':
        return onRequest;
      case 'on-failure':
      case 'onFailure':
        return onFailure;
      case 'never':
        return never;
      case 'untrusted':
      case 'unless-trusted':
      case 'unlessTrusted':
        return untrusted;
      case 'granular':
        return granular;
      case null:
      case '':
        return null;
      default:
        return policy.toString();
    }
  }
}

class SessionSandboxModes {
  static const readOnly = 'read-only';
  static const workspaceWrite = 'workspace-write';
  static const dangerFullAccess = 'danger-full-access';

  const SessionSandboxModes._();

  static String? normalize(dynamic mode) {
    switch (mode?.toString()) {
      case 'workspace-write':
      case 'workspaceWrite':
        return workspaceWrite;
      case 'read-only':
      case 'readOnly':
        return readOnly;
      case 'danger-full-access':
      case 'dangerFullAccess':
        return dangerFullAccess;
      case null:
      case '':
        return null;
      default:
        return mode.toString();
    }
  }
}

class SessionEventTypes {
  static const started = 'session.started';
  static const statusChanged = 'session.status_changed';
  static const turnStarted = 'session.turn_started';
  static const turnCompleted = 'session.turn_completed';
  static const turnFailed = 'session.turn_failed';
  static const userMessage = 'session.user_message';
  static const message = 'session.message';
  static const messageDelta = 'session.message_delta';
  static const output = 'session.output';
  static const plan = 'session.plan';
  static const planDelta = 'session.plan_delta';
  static const planUpdated = 'session.plan_updated';
  static const reasoning = 'session.reasoning';
  static const reasoningSummaryDelta = 'session.reasoning_summary_delta';
  static const reasoningTextDelta = 'session.reasoning_text_delta';
  static const reasoningSummaryPart = 'session.reasoning_summary_part';
  static const diffUpdated = 'session.diff_updated';
  static const commandCompleted = 'session.command_completed';
  static const commandOutputDelta = 'session.command_output_delta';
  static const fileWrite = 'session.file_write';
  static const fileRead = 'session.file_read';
  static const fileChangeOutputDelta = 'session.file_change_output_delta';
  static const mcpToolCompleted = 'session.mcp_tool_completed';
  static const approvalRequest = 'session.approval_request';
  static const approvalResolved = 'session.approval_resolved';
  static const error = 'session.error';
  static const exited = 'session.exited';
  static const itemStarted = 'session.item_started';
  static const itemCompleted = 'session.item_completed';

  const SessionEventTypes._();

  static String normalize(String eventType) {
    switch (eventType) {
      case 'approval.requested':
        return approvalRequest;
      case 'approval.resolved':
        return approvalResolved;
      case 'thread/status/changed':
        return statusChanged;
      case 'thread/closed':
        return exited;
      case 'item.agent_message.delta':
      case 'item/agentMessage/delta':
        return messageDelta;
      case 'item/plan/delta':
        return planDelta;
      case 'item/reasoning/summaryTextDelta':
        return reasoningSummaryDelta;
      case 'item/reasoning/textDelta':
        return reasoningTextDelta;
      case 'item/reasoning/summaryPartAdded':
        return reasoningSummaryPart;
      case 'item/commandExecution/outputDelta':
        return commandOutputDelta;
      case 'item/fileChange/outputDelta':
        return fileChangeOutputDelta;
      case 'turn/plan/updated':
        return planUpdated;
      case 'turn/diff/updated':
        return diffUpdated;
      default:
        return eventType;
    }
  }
}

class SessionItemTypes {
  static const userMessage = 'user_message';
  static const agentMessage = 'agent_message';
  static const commandExecution = 'command_execution';
  static const fileChange = 'file_change';
  static const fileRead = 'file_read';
  static const mcpToolCall = 'mcp_tool_call';
  static const plan = 'plan';
  static const reasoning = 'reasoning';
  static const diff = 'diff';

  const SessionItemTypes._();

  static String normalize(String itemType) {
    switch (itemType) {
      case 'userMessage':
        return userMessage;
      case 'agentMessage':
        return agentMessage;
      case 'commandExecution':
        return commandExecution;
      case 'fileChange':
        return fileChange;
      case 'fileRead':
        return fileRead;
      case 'mcpToolCall':
        return mcpToolCall;
      case 'dynamicToolCall':
        return 'dynamic_tool_call';
      case 'collabToolCall':
        return 'collab_tool_call';
      case 'webSearch':
        return 'web_search';
      case 'imageView':
        return 'image_view';
      case 'contextCompaction':
        return 'context_compaction';
      default:
        return itemType;
    }
  }
}

String? canonicalProviderId(Map<String, dynamic> session) {
  final providerId = session['provider_id']?.toString();
  if (providerId != null && providerId.isNotEmpty) return providerId;
  return null;
}
