// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Magent';

  @override
  String get appTitleShort => 'Magent';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get confirm => 'Confirm';

  @override
  String get back => 'Back';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get noData => 'No data';

  @override
  String get navAgents => 'Agents';

  @override
  String get navProjects => 'Projects';

  @override
  String get navSettings => 'Settings';

  @override
  String get agentsTitle => 'Agents';

  @override
  String get agentsEmpty => 'No agents configured';

  @override
  String get agentsAdd => 'Add Agent';

  @override
  String get agentsConnect => 'Connect Agent';

  @override
  String get agentsEdit => 'Edit Agent';

  @override
  String get agentsDelete => 'Delete Agent';

  @override
  String agentsDeleteConfirm(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get agentsActive => 'Active';

  @override
  String get agentsEnter => 'Enter';

  @override
  String get agentsName => 'Name';

  @override
  String get agentsUrl => 'URL';

  @override
  String get agentsToken => 'Token';

  @override
  String get agentsSaveFailed => 'Save failed';

  @override
  String get agentsConnectFailed => 'Connection failed';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectsEmpty => 'No projects yet';

  @override
  String get projectsCreate => 'Create Project';

  @override
  String get projectsDelete => 'Delete Project';

  @override
  String projectsDeleteConfirm(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get projectsName => 'Project Name';

  @override
  String get projectsDirectory => 'Directory';

  @override
  String get projectsSelectDir => 'Select directory...';

  @override
  String get projectsCreateFailed => 'Create failed';

  @override
  String get projectsDeleteFailed => 'Delete failed';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsCreate => 'New Session';

  @override
  String get sessionsEmpty => 'No sessions';

  @override
  String get sessionsProvider => 'Provider';

  @override
  String get sessionsNoProvider =>
      'No providers available. Install codex, claude, or aider.';

  @override
  String get sessionsModel => 'Model';

  @override
  String get sessionsModelDefault => 'Default';

  @override
  String get sessionsEffort => 'Reasoning Effort';

  @override
  String get sessionsApproval => 'Approval Policy';

  @override
  String get sessionsSandbox => 'Sandbox Mode';

  @override
  String get sessionsPrompt => 'Prompt';

  @override
  String get sessionsPromptHint => 'Describe what you want to do...';

  @override
  String get sessionsCreateBtn => 'Start Session';

  @override
  String get sessionsCreateFailed => 'Failed to create session';

  @override
  String get sessionsQuickQuestion => 'Quick Question';

  @override
  String get sessionsAutoCode => 'Auto Code';

  @override
  String get sessionsFullTrust => 'Full Trust';

  @override
  String get approvalStrict => 'Strict';

  @override
  String get approvalNormal => 'Normal';

  @override
  String get approvalAuto => 'Auto';

  @override
  String get sandboxReadOnly => 'Read Only';

  @override
  String get sandboxWorkspace => 'Workspace';

  @override
  String get sandboxFull => 'Full Access';

  @override
  String get effortLow => 'Low';

  @override
  String get effortMedium => 'Medium';

  @override
  String get effortHigh => 'High';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatInputHint => 'Type a message...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatInterrupt => 'Interrupt';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatApprove => 'Approve';

  @override
  String get chatDeny => 'Deny';

  @override
  String get gitTitle => 'Git Status';

  @override
  String get gitCommit => 'Commit';

  @override
  String get gitPush => 'Push';

  @override
  String get gitStage => 'Stage';

  @override
  String get gitUnstage => 'Unstage';

  @override
  String get gitDiscard => 'Discard';

  @override
  String get gitCommitLog => 'Commit Log';

  @override
  String get gitBranches => 'Branches';

  @override
  String get gitNoCommits => 'No commits found';

  @override
  String get gitNoBranches => 'No branches found';

  @override
  String get gitCommitMsg => 'Commit message';

  @override
  String get gitCommitFailed => 'Commit failed';

  @override
  String get gitPushFailed => 'Push failed';

  @override
  String get filesTitle => 'Files';

  @override
  String get filesEmpty => 'Empty directory';

  @override
  String get filesNoAgent => 'No agent connected';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAgent => 'Agent';

  @override
  String get settingsManageAgents => 'Manage Agents';

  @override
  String get settingsManageAgentsSub =>
      'Add, edit, or remove agent connections';

  @override
  String get settingsProviders => 'Providers';

  @override
  String get settingsProvidersSub =>
      'View available AI providers and capabilities';

  @override
  String get settingsDefaultCli => 'Default Provider';

  @override
  String get settingsDefaultCliSub => 'Default AI provider for new sessions';

  @override
  String get settingsGit => 'Git Operations';

  @override
  String get settingsGitManage => 'Git Management';

  @override
  String get settingsGitManageSub => 'Status, commit log, and branches';

  @override
  String get settingsCommitPush => 'Commit & Push';

  @override
  String get settingsCommitPushSub => 'Commit changes and push to remote';

  @override
  String get settingsCommitLog => 'Commit Log';

  @override
  String get settingsCommitLogSub => 'View commit history';

  @override
  String get settingsBranchesSub => 'View and switch branches';

  @override
  String get settingsCache => 'Cache';

  @override
  String get settingsCacheManage => 'Cache Management';

  @override
  String get settingsCacheManageSub => 'View and clear cached data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';
}
