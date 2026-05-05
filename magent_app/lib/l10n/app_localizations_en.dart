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
  String get more => 'More';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get noData => 'No data';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get agentConnectionFailure => 'Connection failed. Check the agent.';

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
  String get agentsDefaultName => 'My Agent';

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
  String get sessionsLoadConfigFailed => 'Failed to load config';

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
  String get chatSyncingTitle => 'Syncing conversation';

  @override
  String get chatSyncingSubtitle => 'Loading the latest messages...';

  @override
  String get chatApprove => 'Approve';

  @override
  String get chatDeny => 'Deny';

  @override
  String get gitTitle => 'Git Status';

  @override
  String get gitChanges => 'Changes';

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
  String get gitCurrentBranch => 'current';

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
  String get settingsSession => 'Sessions';

  @override
  String get settingsSessionOpenAtBottom =>
      'Open sessions at the latest message';

  @override
  String get settingsSessionOpenAtBottomSub =>
      'Show the last conversation when entering a session';

  @override
  String get settingsShowAiCommitSessions => 'Show AI commit sessions';

  @override
  String get settingsShowAiCommitSessionsSub =>
      'Include sessions created only for commit message generation';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsViewerFontSize => 'File viewer font size';

  @override
  String get settingsViewerFontSizeSub =>
      'Adjust font size in code, text, Markdown source and diff views';

  @override
  String get viewerFontSizeSmall => 'Small';

  @override
  String get viewerFontSizeMedium => 'Medium';

  @override
  String get viewerFontSizeLarge => 'Large';

  @override
  String get viewerFontSizeReset => 'Reset';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsGit => 'Git Operations';

  @override
  String get settingsGitManage => 'Git Management';

  @override
  String get settingsGitManageSub => 'Status, commit log, and branches';

  @override
  String get settingsAiCommitModel => 'AI commit model';

  @override
  String get settingsAiCommitModelSub =>
      'Provider-specific model and reasoning effort for commit message generation';

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

  @override
  String get fieldRequired => 'Required';

  @override
  String get select => 'Select';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get processing => 'Processing...';

  @override
  String get noAgentConnected => 'No agent connected';

  @override
  String get untitledProject => 'Untitled Project';

  @override
  String get agentSelected => 'Agent selected';

  @override
  String get agentUpdated => 'Agent updated';

  @override
  String get agentConnected => 'Connected successfully';

  @override
  String agentRemoved(Object name) {
    return '\"$name\" removed';
  }

  @override
  String get agentsRemove => 'Remove Agent';

  @override
  String agentsRemoveConfirm(Object name) {
    return 'Remove \"$name\"? This will disconnect from this agent.';
  }

  @override
  String get agentsRemoveAction => 'Remove';

  @override
  String get agentsEmptySub =>
      'Connect a local or remote agent to manage projects and sessions.';

  @override
  String get agentsSaveVerify => 'Save & Verify';

  @override
  String get projectsEmptySub =>
      'Add a workspace directory to create sessions, review changes, and browse files.';

  @override
  String get statusRunning => 'Running';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusStopped => 'Stopped';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusLost => 'Lost';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get sessionsEmptyYet => 'No sessions yet';

  @override
  String get sessionsEmptySub => 'Start a new AI coding session';

  @override
  String get sessionsActive => 'Active';

  @override
  String get sessionsArchived => 'Archived';

  @override
  String get sessionsArchivedEmpty => 'No archived sessions';

  @override
  String get sessionsArchivedEmptySub => 'Archived sessions will appear here';

  @override
  String get sessionArchive => 'Archive';

  @override
  String get sessionUnarchive => 'Unarchive';

  @override
  String get sessionArchiveFailed => 'Archive failed';

  @override
  String get sessionUnarchiveFailed => 'Unarchive failed';

  @override
  String get sessionDeleteTitle => 'Delete session';

  @override
  String sessionDeleteConfirm(Object title) {
    return 'Delete \"$title\"? This removes the local Codex history JSONL and cannot be undone.';
  }

  @override
  String get sessionDeleteFailed => 'Delete failed';

  @override
  String get sessionPurposeAiCommit => 'AI commit';

  @override
  String sessionsLoadMore(int count) {
    return '$count older sessions hidden. Tap to load.';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get timeNow => 'now';

  @override
  String get chatSendFailed => 'Send failed';

  @override
  String get chatStartFailed => 'Start failed';

  @override
  String get chatInterruptFailed => 'Interrupt failed';

  @override
  String get chatStopFailed => 'Stop failed';

  @override
  String get chatApprovalFailed => 'Approval failed';

  @override
  String get chatLoadSkillsFailed => 'Failed to load skills';

  @override
  String get chatRunningTitle => 'Currently processing';

  @override
  String get chatRunningSubtitle => 'Choose how to handle this new message';

  @override
  String get chatQueueMessage => 'Add to queue';

  @override
  String get chatQueueMessageSub =>
      'Send automatically after the current reply finishes.';

  @override
  String get chatInterruptAndSend => 'Interrupt and send';

  @override
  String get chatInterruptAndSendSub =>
      'Stop the current reply, then process this message immediately.';

  @override
  String get chatSessionLostTitle => 'Session unavailable';

  @override
  String get chatSessionLostContent =>
      'This session no longer exists on the server. It may have been removed after the server restarted. Create a new session to continue.';

  @override
  String get chatInterruptSent => 'Interrupt request sent';

  @override
  String get chatStopSession => 'Stop session';

  @override
  String get chatStopConfirm => 'Stop this session?';

  @override
  String get chatSessionStopped => 'Session stopped';

  @override
  String get chatNoSkills => 'No skills available';

  @override
  String get chatMissingProject =>
      'Current session is missing project information';

  @override
  String get chatRefresh => 'Refresh';

  @override
  String get chatSettings => 'Session settings';

  @override
  String get chatSettingsTitle => 'Session settings';

  @override
  String get chatSettingsModel => 'Model';

  @override
  String get chatSettingsEffort => 'Reasoning effort';

  @override
  String get chatSettingsApproval => 'Approval policy';

  @override
  String get chatSettingsSandbox => 'Sandbox mode';

  @override
  String get chatSettingsApply => 'Apply';

  @override
  String get chatSettingsHint =>
      'Client-only override applied to your next send; the server does not persist these.';

  @override
  String get chatCreateNewSession => 'Create new session';

  @override
  String get chatSessionEnded => 'Session ended';

  @override
  String get chatNoMessages => 'No messages yet';

  @override
  String get chatSessionNotStarted => 'Session not started';

  @override
  String get chatStarting => 'Starting...';

  @override
  String get chatStartSession => 'Start session';

  @override
  String get chatNewSession => 'New session';

  @override
  String get chatPlan => 'Plan';

  @override
  String get chatReasoningSummary => 'Reasoning summary';

  @override
  String get chatDiffSummary => 'Change summary';

  @override
  String get chatCommandOutput => 'Command output';

  @override
  String get chatFileChangeOutput => 'File change output';

  @override
  String get chatCommand => 'Command';

  @override
  String get chatFileChange => 'File change';

  @override
  String get chatReadFile => 'Read file';

  @override
  String get chatTurnStarted => 'Started processing...';

  @override
  String get chatTurnCompleted => 'Processing completed';

  @override
  String get chatTurnFailed => 'Processing failed';

  @override
  String get chatApprovalResolved => 'Approval handled';

  @override
  String chatExited(Object code) {
    return 'Session exited (code: $code)';
  }

  @override
  String get chatPlanUpdated => 'Plan updated';

  @override
  String get chatReasoningUpdated => 'Reasoning summary updated';

  @override
  String get chatFileUpdated => 'File updated';

  @override
  String chatFileCount(int count) {
    return '$count files';
  }

  @override
  String chatRunningQueued(int count) {
    return 'Generating reply, $count messages queued';
  }

  @override
  String get chatRunningHint =>
      'Generating reply. Send again to queue or interrupt.';

  @override
  String chatQueuedInputs(int count) {
    return '$count messages queued';
  }

  @override
  String get chatTemplatesTooltip => 'History and templates';

  @override
  String get chatSkillsTooltip => 'Use skill';

  @override
  String get chatFilesTooltip => 'Reference workspace path';

  @override
  String get chatChooseSkill => 'Choose skill';

  @override
  String get chatChooseWorkspaceFile => 'Choose workspace file or folder';

  @override
  String get chatContextCompacted => 'Conversation compressed';

  @override
  String chatCollapsedEvents(int count) {
    return '$count older messages hidden';
  }

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get approvalRequired => 'Approval required';

  @override
  String get approvalUnknownAction => 'Unknown operation';

  @override
  String get approvalAllowSession => 'Allow for session';

  @override
  String get templatesSaveAs => 'Save as template';

  @override
  String get templatesNameHint => 'Template name';

  @override
  String get templatesRecent => 'Recent messages';

  @override
  String get templatesSaved => 'Saved templates';

  @override
  String get templatesNoRecent => 'No recent messages';

  @override
  String get templatesNoSaved => 'No saved templates';

  @override
  String get templatesDelete => 'Delete template';

  @override
  String get providersTitle => 'Providers';

  @override
  String get providersEmpty => 'No providers found';

  @override
  String get providersAvailable => 'Available';

  @override
  String get providersUnavailable => 'Unavailable';

  @override
  String get providersNotAvailable => 'Not available';

  @override
  String get providersBinary => 'Binary';

  @override
  String get providersMode => 'Mode';

  @override
  String get providersCapabilities => 'Capabilities';

  @override
  String get providersUnknown => 'Unknown';

  @override
  String get capabilityResume => 'Resume';

  @override
  String get capabilityFork => 'Fork';

  @override
  String get capabilitySteer => 'Steer';

  @override
  String get capabilityInterrupt => 'Interrupt';

  @override
  String get capabilityCompact => 'Compact';

  @override
  String get capabilityRollback => 'Rollback';

  @override
  String get capabilityApproval => 'Approval';

  @override
  String get capabilityFileSystem => 'File System';

  @override
  String get capabilityMcp => 'MCP';

  @override
  String get capabilityPty => 'PTY';

  @override
  String get capabilityStreaming => 'Streaming';

  @override
  String get capabilityStructuredOutput => 'Structured Output';

  @override
  String get cacheClear => 'Clear';

  @override
  String get cacheClearAll => 'Clear All';

  @override
  String get cacheClearAllCaches => 'Clear All Caches';

  @override
  String get cacheClearAllDisplayCaches => 'Clear All Display Caches';

  @override
  String get cacheClearConfirm =>
      'This removes local display caches only. Provider history, Git state, and files remain the source of truth.';

  @override
  String get cacheGitDisplay => 'Git Display Cache';

  @override
  String get cacheFileDisplay => 'File Display Cache';

  @override
  String get cacheSessionDisplay => 'Session Display Cache';

  @override
  String cacheCleared(Object name) {
    return '$name cache cleared';
  }

  @override
  String cacheEntries(int count) {
    return '$count entries';
  }

  @override
  String get gitStatus => 'Status';

  @override
  String get gitLog => 'Log';

  @override
  String get gitPull => 'Pull';

  @override
  String get gitRoot => 'Root';

  @override
  String get gitPullFailed => 'Pull failed';

  @override
  String get gitPullSuccessful => 'Pull successful';

  @override
  String get gitPushSuccessful => 'Push successful';

  @override
  String get gitStageFailed => 'Stage failed';

  @override
  String get gitUnstageFailed => 'Unstage failed';

  @override
  String get gitDiscardFailed => 'Discard failed';

  @override
  String get gitDiscardChanges => 'Discard changes';

  @override
  String gitDiscardChangesConfirm(int count) {
    return 'Discard changes in $count files? This cannot be undone.';
  }

  @override
  String get gitForcePush => 'Force Push';

  @override
  String get gitForcePushConfirm =>
      'Force push will overwrite remote history. Continue?';

  @override
  String get gitStaged => 'Staged';

  @override
  String get gitUnstaged => 'Unstaged';

  @override
  String get gitWorkingTreeClean => 'Working tree clean';

  @override
  String get gitNoStagedFiles => 'No staged files';

  @override
  String get gitNoUnstagedFiles => 'No unstaged files';

  @override
  String get gitNoFilesChanged => 'No files changed';

  @override
  String get gitBinaryFile => 'Binary file';

  @override
  String get gitBinaryFileDiffUnavailable =>
      'Binary file - cannot display diff';

  @override
  String get gitNoTextChanges => 'No text changes';

  @override
  String get gitCannotDisplayImage => 'Cannot display image - no file API';

  @override
  String get gitImageDataUnavailable => 'Image data not available';

  @override
  String get gitLoadImageFailed => 'Failed to load image';

  @override
  String get gitLoadDiffFailed => 'Failed to load Diff';

  @override
  String get gitAiMessageGenerated => 'AI message generated';

  @override
  String get gitAiReturnedEmpty => 'AI returned empty response';

  @override
  String get gitAiSuggestionFailed => 'AI suggestion failed';

  @override
  String get gitCommitMessageRequired => 'Commit message is required';

  @override
  String get gitCommitSuccessful => 'Commit successful';

  @override
  String get gitCommitMessageHint => 'feat: describe your changes...';

  @override
  String get gitAiSuggest => 'AI suggest';

  @override
  String get gitGenerating => 'Generating...';

  @override
  String get gitAiGenerateMessage => 'AI Generate Message';

  @override
  String get gitStageAllChanges => 'Stage all changes (-a)';

  @override
  String get wrap => 'Wrap';

  @override
  String get noWrap => 'No wrap';

  @override
  String get enableWrap => 'Enable wrap';

  @override
  String get disableWrap => 'Disable wrap';

  @override
  String get viewerSource => 'Source';

  @override
  String get viewerRender => 'Render';

  @override
  String get viewerSourceMode => 'Source mode';

  @override
  String get viewerRenderMode => 'Render mode';

  @override
  String get loadMore => 'Load more';

  @override
  String get filesReadFailed => 'Read failed';

  @override
  String get filesLoadFailed => 'Load failed';

  @override
  String get filesNoSubdirectories => 'No subdirectories';

  @override
  String filesSelectPath(Object path) {
    return 'Select: $path';
  }
}
