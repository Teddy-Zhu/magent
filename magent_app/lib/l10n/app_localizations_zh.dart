// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Magent';

  @override
  String get appTitleShort => 'Magent';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get create => '创建';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get confirm => '确认';

  @override
  String get back => '返回';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制到剪贴板';

  @override
  String get more => '更多';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get noData => '暂无数据';

  @override
  String get operationFailed => '操作失败';

  @override
  String get agentConnectionFailure => '连接失败，请检查 agent';

  @override
  String get navAgents => '代理';

  @override
  String get navProjects => '项目';

  @override
  String get navSettings => '设置';

  @override
  String get agentsTitle => '代理';

  @override
  String get agentsEmpty => '暂无代理配置';

  @override
  String get agentsAdd => '添加代理';

  @override
  String get agentsConnect => '连接代理';

  @override
  String get agentsEdit => '编辑代理';

  @override
  String get agentsDelete => '删除代理';

  @override
  String agentsDeleteConfirm(Object name) {
    return '确定删除「$name」？此操作不可撤销。';
  }

  @override
  String get agentsActive => '当前';

  @override
  String get agentsEnter => '进入';

  @override
  String get agentsName => '名称';

  @override
  String get agentsUrl => '地址';

  @override
  String get agentsToken => '令牌';

  @override
  String get agentsSaveFailed => '保存失败';

  @override
  String get agentsConnectFailed => '连接失败';

  @override
  String get agentsDefaultName => '我的 Agent';

  @override
  String get projectsTitle => '项目';

  @override
  String get projectsEmpty => '暂无项目';

  @override
  String get projectsCreate => '创建项目';

  @override
  String get projectsDelete => '删除项目';

  @override
  String projectsDeleteConfirm(Object name) {
    return '确定删除「$name」？此操作不可撤销。';
  }

  @override
  String get projectsName => '项目名称';

  @override
  String get projectsDirectory => '目录';

  @override
  String get projectsSelectDir => '选择目录...';

  @override
  String get projectsCreateFailed => '创建失败';

  @override
  String get projectsDeleteFailed => '删除失败';

  @override
  String get sessionsTitle => '会话';

  @override
  String get sessionsCreate => '新建会话';

  @override
  String get sessionsEmpty => '暂无会话';

  @override
  String get sessionsProvider => '提供者';

  @override
  String get sessionsNoProvider => '无可用提供者，请安装 codex、claude 或 aider。';

  @override
  String get sessionsModel => '模型';

  @override
  String get sessionsModelDefault => '默认';

  @override
  String get sessionsEffort => '推理强度';

  @override
  String get sessionsApproval => '审批策略';

  @override
  String get sessionsSandbox => '沙箱模式';

  @override
  String get sessionsPrompt => '提示词';

  @override
  String get sessionsPromptHint => '描述你想做什么...';

  @override
  String get sessionsCreateBtn => '启动会话';

  @override
  String get sessionsCreateFailed => '创建会话失败';

  @override
  String get sessionsLoadConfigFailed => '加载配置失败';

  @override
  String get sessionsQuickQuestion => '快速提问';

  @override
  String get sessionsAutoCode => '自动编码';

  @override
  String get sessionsFullTrust => '完全信任';

  @override
  String get approvalStrict => '严格';

  @override
  String get approvalNormal => '普通';

  @override
  String get approvalAuto => '自动';

  @override
  String get sandboxReadOnly => '只读';

  @override
  String get sandboxWorkspace => '工作区';

  @override
  String get sandboxFull => '完全访问';

  @override
  String get effortLow => 'low';

  @override
  String get effortMedium => 'medium';

  @override
  String get effortHigh => 'high';

  @override
  String get chatTitle => '对话';

  @override
  String get chatInputHint => '输入消息...';

  @override
  String get chatSend => '发送';

  @override
  String get chatInterrupt => '中断';

  @override
  String get chatStop => '停止';

  @override
  String get chatSyncingTitle => '正在同步对话';

  @override
  String get chatSyncingSubtitle => '加载最新消息中...';

  @override
  String get chatApprove => '批准';

  @override
  String get chatDeny => '拒绝';

  @override
  String get gitTitle => 'Git 状态';

  @override
  String get gitChanges => '变更';

  @override
  String get gitCommit => '提交';

  @override
  String get gitPush => '推送';

  @override
  String get gitStage => '暂存';

  @override
  String get gitUnstage => '取消暂存';

  @override
  String get gitDiscard => '丢弃';

  @override
  String get gitCommitLog => '提交记录';

  @override
  String get gitBranches => '分支';

  @override
  String get gitNoCommits => '暂无提交记录';

  @override
  String get gitNoBranches => '暂无分支';

  @override
  String get gitCurrentBranch => '当前';

  @override
  String get gitCommitMsg => '提交信息';

  @override
  String get gitCommitFailed => '提交失败';

  @override
  String get gitPushFailed => '推送失败';

  @override
  String get filesTitle => '文件';

  @override
  String get filesEmpty => '空目录';

  @override
  String get filesNoAgent => '未连接代理';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAgent => '代理';

  @override
  String get settingsManageAgents => '管理代理';

  @override
  String get settingsManageAgentsSub => '添加、编辑或移除代理连接';

  @override
  String get settingsProviders => '提供者';

  @override
  String get settingsProvidersSub => '查看可用的 AI 提供者及能力';

  @override
  String get settingsDefaultCli => '默认提供者';

  @override
  String get settingsDefaultCliSub => '新建会话时的默认 AI 提供者';

  @override
  String get settingsSession => '会话';

  @override
  String get settingsSessionOpenAtBottom => '进入会话默认定位到底部';

  @override
  String get settingsSessionOpenAtBottomSub => '打开会话时自动显示最后一条对话';

  @override
  String get settingsShowAiCommitSessions => '显示 AI 生成提交信息会话';

  @override
  String get settingsShowAiCommitSessionsSub => '在会话列表中包含仅用于生成提交信息的会话';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsViewerFontSize => '文件查看字号';

  @override
  String get settingsViewerFontSizeSub => '调整代码、文本、Markdown 源码、Diff 的字号';

  @override
  String get viewerFontSizeSmall => '小';

  @override
  String get viewerFontSizeMedium => '中';

  @override
  String get viewerFontSizeLarge => '大';

  @override
  String get viewerFontSizeReset => '重置';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '亮色';

  @override
  String get themeDark => '暗色';

  @override
  String get settingsGit => 'Git 操作';

  @override
  String get settingsGitManage => 'Git 管理';

  @override
  String get settingsGitManageSub => '状态、提交记录和分支';

  @override
  String get settingsAiCommitModel => 'AI 提交信息模型';

  @override
  String get settingsAiCommitModelSub => '按提供者设置生成提交信息使用的模型和推理强度';

  @override
  String get settingsCommitPush => '提交与推送';

  @override
  String get settingsCommitPushSub => '提交更改并推送到远程';

  @override
  String get settingsCommitLog => '提交记录';

  @override
  String get settingsCommitLogSub => '查看提交历史';

  @override
  String get settingsBranchesSub => '查看和切换分支';

  @override
  String get settingsCache => '缓存';

  @override
  String get settingsCacheManage => '缓存管理';

  @override
  String get settingsCacheManageSub => '查看和清除缓存数据';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get fieldRequired => '必填';

  @override
  String get select => '选择';

  @override
  String selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get processing => '处理中...';

  @override
  String get noAgentConnected => '未连接 Agent';

  @override
  String get untitledProject => '未命名项目';

  @override
  String get agentSelected => '已选择 Agent';

  @override
  String get agentUpdated => 'Agent 已更新';

  @override
  String get agentConnected => '连接成功';

  @override
  String agentRemoved(Object name) {
    return '已移除「$name」';
  }

  @override
  String get agentsRemove => '移除 Agent';

  @override
  String agentsRemoveConfirm(Object name) {
    return '确定移除「$name」？这会断开与该 Agent 的连接。';
  }

  @override
  String get agentsRemoveAction => '移除';

  @override
  String get agentsEmptySub => '连接本地或远程 Agent 后即可管理项目和会话。';

  @override
  String get agentsSaveVerify => '保存并验证';

  @override
  String get projectsEmptySub => '添加一个工作目录后即可创建会话、查看变更和浏览文件。';

  @override
  String get statusRunning => '运行中';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusStopped => '已停止';

  @override
  String get statusFailed => '失败';

  @override
  String get statusLost => '已丢失';

  @override
  String get statusUnknown => '未知';

  @override
  String get sessionsEmptyYet => '暂无会话';

  @override
  String get sessionsEmptySub => '启动一个新的 AI 编码会话';

  @override
  String get sessionsActive => '活跃';

  @override
  String get sessionsArchived => '归档';

  @override
  String get sessionsArchivedEmpty => '暂无归档会话';

  @override
  String get sessionsArchivedEmptySub => '归档后的会话会显示在这里';

  @override
  String get sessionArchive => '归档';

  @override
  String get sessionUnarchive => '取消归档';

  @override
  String get sessionArchiveFailed => '归档失败';

  @override
  String get sessionUnarchiveFailed => '取消归档失败';

  @override
  String get sessionDeleteTitle => '删除会话';

  @override
  String sessionDeleteConfirm(Object title) {
    return '确定删除「$title」？这会移除本地 Codex 历史 JSONL，且不可撤销。';
  }

  @override
  String get sessionDeleteFailed => '删除失败';

  @override
  String get sessionPurposeAiCommit => 'AI 提交';

  @override
  String sessionsLoadMore(int count) {
    return '还有 $count 个更早会话，点击加载';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String timeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String get timeNow => '刚刚';

  @override
  String get chatSendFailed => '发送失败';

  @override
  String get chatStartFailed => '启动失败';

  @override
  String get chatInterruptFailed => '中断失败';

  @override
  String get chatStopFailed => '停止失败';

  @override
  String get chatApprovalFailed => '审批失败';

  @override
  String get chatLoadSkillsFailed => '加载技能失败';

  @override
  String get chatRunningTitle => '当前正在处理';

  @override
  String get chatRunningSubtitle => '选择这条新消息的处理方式';

  @override
  String get chatQueueMessage => '加入等待队列';

  @override
  String get chatQueueMessageSub => '当前回复完成后自动发送，适合追加新任务。';

  @override
  String get chatInterruptAndSend => '打断并发送';

  @override
  String get chatInterruptAndSendSub => '停止当前回复，再立刻处理这条消息。';

  @override
  String get chatSessionLostTitle => '会话已失效';

  @override
  String get chatSessionLostContent => '此会话在服务器上已不存在，可能是因为服务器重启。请创建新会话。';

  @override
  String get chatInterruptSent => '已发送中断请求';

  @override
  String get chatStopSession => '停止会话';

  @override
  String get chatStopConfirm => '确定要停止此会话吗？';

  @override
  String get chatSessionStopped => '会话已停止';

  @override
  String get chatNoSkills => '当前没有可用技能';

  @override
  String get chatMissingProject => '当前会话缺少项目信息';

  @override
  String get chatRefresh => '刷新';

  @override
  String get chatSettings => '会话设置';

  @override
  String get chatSettingsTitle => '会话设置';

  @override
  String get chatSettingsModel => '模型';

  @override
  String get chatSettingsEffort => '推理强度';

  @override
  String get chatSettingsApproval => '审批策略';

  @override
  String get chatSettingsSandbox => '沙箱模式';

  @override
  String get chatSettingsApply => '应用';

  @override
  String get chatSettingsHint => '仅本端生效，下次发送消息时携带；不会修改服务端会话默认设置。';

  @override
  String get chatCreateNewSession => '创建新会话';

  @override
  String get chatSessionEnded => '会话已结束';

  @override
  String get chatNoMessages => '暂无消息';

  @override
  String get chatSessionNotStarted => '会话未启动';

  @override
  String get chatStarting => '启动中...';

  @override
  String get chatStartSession => '启动会话';

  @override
  String get chatNewSession => '新建会话';

  @override
  String get chatPlan => '计划';

  @override
  String get chatReasoningSummary => '推理摘要';

  @override
  String get chatDiffSummary => '变更摘要';

  @override
  String get chatCommandOutput => '命令输出';

  @override
  String get chatFileChangeOutput => '文件变更输出';

  @override
  String get chatCommand => '命令';

  @override
  String get chatFileChange => '文件变更';

  @override
  String get chatReadFile => '读取文件';

  @override
  String get chatTurnStarted => '开始处理...';

  @override
  String get chatTurnCompleted => '处理完成';

  @override
  String get chatTurnFailed => '处理失败';

  @override
  String get chatApprovalResolved => '审批已处理';

  @override
  String chatExited(Object code) {
    return '会话已退出 (code: $code)';
  }

  @override
  String get chatPlanUpdated => '计划已更新';

  @override
  String get chatReasoningUpdated => '推理摘要已更新';

  @override
  String get chatFileUpdated => '文件已更新';

  @override
  String chatFileCount(int count) {
    return '$count 个文件';
  }

  @override
  String chatRunningQueued(int count) {
    return '正在生成回复，队列中还有 $count 条消息';
  }

  @override
  String get chatRunningHint => '正在生成回复，继续发送可选择排队或打断后发送';

  @override
  String chatQueuedInputs(int count) {
    return '已加入等待队列：$count 条';
  }

  @override
  String get chatTemplatesTooltip => '历史消息和模板';

  @override
  String get chatSkillsTooltip => '调用技能';

  @override
  String get chatFilesTooltip => '引用工作区路径';

  @override
  String get chatChooseSkill => '选择技能';

  @override
  String get chatChooseWorkspaceFile => '选择工作区文件或目录';

  @override
  String get chatContextCompacted => '对话已压缩';

  @override
  String get chatLoadOlderMessages => '加载更早消息';

  @override
  String chatCollapsedEvents(int count) {
    return '已折叠 $count 条更早消息';
  }

  @override
  String get expand => '展开';

  @override
  String get collapse => '收起';

  @override
  String get approvalRequired => '需要审批';

  @override
  String get approvalUnknownAction => '未知操作';

  @override
  String get approvalAllowSession => '本次允许';

  @override
  String get templatesSaveAs => '保存为模板';

  @override
  String get templatesNameHint => '模板名称';

  @override
  String get templatesRecent => '最近消息';

  @override
  String get templatesSaved => '保存的模板';

  @override
  String get templatesNoRecent => '暂无最近消息';

  @override
  String get templatesNoSaved => '暂无保存的模板';

  @override
  String get templatesDelete => '删除模板';

  @override
  String get providersTitle => '提供者';

  @override
  String get providersEmpty => '暂无提供者';

  @override
  String get providersAvailable => '可用';

  @override
  String get providersUnavailable => '不可用';

  @override
  String get providersNotAvailable => '不可用';

  @override
  String get providersBinary => '执行文件';

  @override
  String get providersMode => '模式';

  @override
  String get providersCapabilities => '能力';

  @override
  String get providersUnknown => '未知';

  @override
  String get capabilityResume => '恢复会话';

  @override
  String get capabilityFork => '派生会话';

  @override
  String get capabilitySteer => '追加指令';

  @override
  String get capabilityInterrupt => '中断';

  @override
  String get capabilityCompact => '压缩上下文';

  @override
  String get capabilityRollback => '回滚';

  @override
  String get capabilityApproval => '审批';

  @override
  String get capabilityFileSystem => '文件系统';

  @override
  String get capabilityMcp => 'MCP';

  @override
  String get capabilityPty => 'PTY';

  @override
  String get capabilityStreaming => '流式输出';

  @override
  String get capabilityStructuredOutput => '结构化输出';

  @override
  String get cacheClear => '清除';

  @override
  String get cacheClearAll => '全部清除';

  @override
  String get cacheClearAllCaches => '清除所有缓存';

  @override
  String get cacheClearAllDisplayCaches => '清除所有展示缓存';

  @override
  String get cacheClearConfirm => '这只会移除本地展示缓存。Provider 历史、Git 状态和文件仍以真实数据为准。';

  @override
  String get cacheGitDisplay => 'Git 展示缓存';

  @override
  String get cacheFileDisplay => '文件展示缓存';

  @override
  String get cacheSessionDisplay => '会话展示缓存';

  @override
  String cacheCleared(Object name) {
    return '$name 缓存已清除';
  }

  @override
  String cacheEntries(int count) {
    return '$count 条记录';
  }

  @override
  String get gitStatus => '状态';

  @override
  String get gitLog => '记录';

  @override
  String get gitPull => '拉取';

  @override
  String get gitRoot => '根目录';

  @override
  String get gitPullFailed => '拉取失败';

  @override
  String get gitPullSuccessful => '拉取成功';

  @override
  String get gitPushSuccessful => '推送成功';

  @override
  String get gitStageFailed => '暂存失败';

  @override
  String get gitUnstageFailed => '取消暂存失败';

  @override
  String get gitDiscardFailed => '丢弃失败';

  @override
  String get gitDiscardChanges => '放弃更改';

  @override
  String gitDiscardChangesConfirm(int count) {
    return '确定放弃 $count 个文件的更改？此操作不可撤销。';
  }

  @override
  String get gitForcePush => '强制推送';

  @override
  String get gitForcePushConfirm => '强制推送会覆盖远端历史，是否继续？';

  @override
  String get gitStaged => '已暂存';

  @override
  String get gitUnstaged => '未暂存';

  @override
  String get gitWorkingTreeClean => '工作区干净';

  @override
  String get gitNoStagedFiles => '暂无已暂存文件';

  @override
  String get gitNoUnstagedFiles => '暂无未暂存文件';

  @override
  String get gitNoFilesChanged => '没有文件变更';

  @override
  String get gitBinaryFile => '二进制文件';

  @override
  String get gitBinaryFileDiffUnavailable => '二进制文件无法显示 Diff';

  @override
  String get gitNoTextChanges => '没有文本变更';

  @override
  String get gitCannotDisplayImage => '无法显示图片：缺少文件 API';

  @override
  String get gitImageDataUnavailable => '图片数据不可用';

  @override
  String get gitLoadImageFailed => '加载图片失败';

  @override
  String get gitLoadDiffFailed => '加载 Diff 失败';

  @override
  String get gitAiMessageGenerated => 'AI 已生成提交信息';

  @override
  String get gitAiReturnedEmpty => 'AI 返回内容为空';

  @override
  String get gitAiSuggestionFailed => 'AI 生成失败';

  @override
  String get gitCommitMessageRequired => '提交信息不能为空';

  @override
  String get gitCommitSuccessful => '提交成功';

  @override
  String get gitCommitMessageHint => 'feat: describe your changes...';

  @override
  String get gitAiSuggest => 'AI 建议';

  @override
  String get gitGenerating => '生成中...';

  @override
  String get gitAiGenerateMessage => 'AI 生成提交信息';

  @override
  String get gitStageAllChanges => '暂存所有更改 (-a)';

  @override
  String get wrap => '换行';

  @override
  String get noWrap => '不换行';

  @override
  String get enableWrap => '启用换行';

  @override
  String get disableWrap => '关闭换行';

  @override
  String get viewerSource => '源码';

  @override
  String get viewerRender => '渲染';

  @override
  String get viewerSourceMode => '源码模式';

  @override
  String get viewerRenderMode => '渲染模式';

  @override
  String get loadMore => '加载更多';

  @override
  String get filesReadFailed => '读取失败';

  @override
  String get filesLoadFailed => '加载失败';

  @override
  String get filesNoSubdirectories => '没有子目录';

  @override
  String filesSelectPath(Object path) {
    return '选择：$path';
  }
}
