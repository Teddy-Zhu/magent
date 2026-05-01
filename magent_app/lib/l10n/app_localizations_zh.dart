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
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get noData => '暂无数据';

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
  String get chatApprove => '批准';

  @override
  String get chatDeny => '拒绝';

  @override
  String get gitTitle => 'Git 状态';

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
  String get settingsGit => 'Git 操作';

  @override
  String get settingsGitManage => 'Git 管理';

  @override
  String get settingsGitManageSub => '状态、提交记录和分支';

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
}
