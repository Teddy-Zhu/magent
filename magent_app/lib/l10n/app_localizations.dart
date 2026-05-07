import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Magent'**
  String get appTitle;

  /// No description provided for @appTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Magent'**
  String get appTitleShort;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @agentConnectionFailure.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check the agent.'**
  String get agentConnectionFailure;

  /// No description provided for @navAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get navAgents;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @agentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentsTitle;

  /// No description provided for @agentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No agents configured'**
  String get agentsEmpty;

  /// No description provided for @agentsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Agent'**
  String get agentsAdd;

  /// No description provided for @agentsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Agent'**
  String get agentsConnect;

  /// No description provided for @agentsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Agent'**
  String get agentsEdit;

  /// No description provided for @agentsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Agent'**
  String get agentsDelete;

  /// No description provided for @agentsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String agentsDeleteConfirm(Object name);

  /// No description provided for @agentsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get agentsActive;

  /// No description provided for @agentsEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get agentsEnter;

  /// No description provided for @agentsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get agentsName;

  /// No description provided for @agentsUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get agentsUrl;

  /// No description provided for @agentsToken.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get agentsToken;

  /// No description provided for @agentsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get agentsSaveFailed;

  /// No description provided for @agentsConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get agentsConnectFailed;

  /// No description provided for @agentsDefaultName.
  ///
  /// In en, this message translates to:
  /// **'My Agent'**
  String get agentsDefaultName;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @projectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get projectsEmpty;

  /// No description provided for @projectsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get projectsCreate;

  /// No description provided for @projectsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get projectsDelete;

  /// No description provided for @projectsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String projectsDeleteConfirm(Object name);

  /// No description provided for @projectsName.
  ///
  /// In en, this message translates to:
  /// **'Project Name'**
  String get projectsName;

  /// No description provided for @projectsDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get projectsDirectory;

  /// No description provided for @projectsSelectDir.
  ///
  /// In en, this message translates to:
  /// **'Select directory...'**
  String get projectsSelectDir;

  /// No description provided for @projectsCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Create failed'**
  String get projectsCreateFailed;

  /// No description provided for @projectsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get projectsDeleteFailed;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsCreate.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get sessionsCreate;

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions'**
  String get sessionsEmpty;

  /// No description provided for @sessionsProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get sessionsProvider;

  /// No description provided for @sessionsNoProvider.
  ///
  /// In en, this message translates to:
  /// **'No providers available. Install codex, claude, or aider.'**
  String get sessionsNoProvider;

  /// No description provided for @sessionsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get sessionsModel;

  /// No description provided for @sessionsModelDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get sessionsModelDefault;

  /// No description provided for @sessionsEffort.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Effort'**
  String get sessionsEffort;

  /// No description provided for @sessionsApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval Policy'**
  String get sessionsApproval;

  /// No description provided for @sessionsSandbox.
  ///
  /// In en, this message translates to:
  /// **'Sandbox Mode'**
  String get sessionsSandbox;

  /// No description provided for @sessionsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get sessionsPrompt;

  /// No description provided for @sessionsPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what you want to do...'**
  String get sessionsPromptHint;

  /// No description provided for @sessionsCreateBtn.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get sessionsCreateBtn;

  /// No description provided for @sessionsCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create session'**
  String get sessionsCreateFailed;

  /// No description provided for @sessionsLoadConfigFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load config'**
  String get sessionsLoadConfigFailed;

  /// No description provided for @sessionsQuickQuestion.
  ///
  /// In en, this message translates to:
  /// **'Quick Question'**
  String get sessionsQuickQuestion;

  /// No description provided for @sessionsAutoCode.
  ///
  /// In en, this message translates to:
  /// **'Auto Code'**
  String get sessionsAutoCode;

  /// No description provided for @sessionsFullTrust.
  ///
  /// In en, this message translates to:
  /// **'Full Trust'**
  String get sessionsFullTrust;

  /// No description provided for @approvalStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get approvalStrict;

  /// No description provided for @approvalNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get approvalNormal;

  /// No description provided for @approvalAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get approvalAuto;

  /// No description provided for @sandboxReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read Only'**
  String get sandboxReadOnly;

  /// No description provided for @sandboxWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get sandboxWorkspace;

  /// No description provided for @sandboxFull.
  ///
  /// In en, this message translates to:
  /// **'Full Access'**
  String get sandboxFull;

  /// No description provided for @effortLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get effortLow;

  /// No description provided for @effortMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get effortMedium;

  /// No description provided for @effortHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get effortHigh;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatInterrupt.
  ///
  /// In en, this message translates to:
  /// **'Interrupt'**
  String get chatInterrupt;

  /// No description provided for @chatStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStop;

  /// No description provided for @chatSyncingTitle.
  ///
  /// In en, this message translates to:
  /// **'Syncing conversation'**
  String get chatSyncingTitle;

  /// No description provided for @chatSyncingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Loading the latest messages...'**
  String get chatSyncingSubtitle;

  /// No description provided for @chatApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get chatApprove;

  /// No description provided for @chatDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get chatDeny;

  /// No description provided for @gitTitle.
  ///
  /// In en, this message translates to:
  /// **'Git Status'**
  String get gitTitle;

  /// No description provided for @gitChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get gitChanges;

  /// No description provided for @gitCommit.
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get gitCommit;

  /// No description provided for @gitPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get gitPush;

  /// No description provided for @gitStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get gitStage;

  /// No description provided for @gitUnstage.
  ///
  /// In en, this message translates to:
  /// **'Unstage'**
  String get gitUnstage;

  /// No description provided for @gitDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get gitDiscard;

  /// No description provided for @gitCommitLog.
  ///
  /// In en, this message translates to:
  /// **'Commit Log'**
  String get gitCommitLog;

  /// No description provided for @gitBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get gitBranches;

  /// No description provided for @gitNoCommits.
  ///
  /// In en, this message translates to:
  /// **'No commits found'**
  String get gitNoCommits;

  /// No description provided for @gitNoBranches.
  ///
  /// In en, this message translates to:
  /// **'No branches found'**
  String get gitNoBranches;

  /// No description provided for @gitCurrentBranch.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get gitCurrentBranch;

  /// No description provided for @gitCommitMsg.
  ///
  /// In en, this message translates to:
  /// **'Commit message'**
  String get gitCommitMsg;

  /// No description provided for @gitCommitFailed.
  ///
  /// In en, this message translates to:
  /// **'Commit failed'**
  String get gitCommitFailed;

  /// No description provided for @gitPushFailed.
  ///
  /// In en, this message translates to:
  /// **'Push failed'**
  String get gitPushFailed;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @filesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty directory'**
  String get filesEmpty;

  /// No description provided for @filesNoAgent.
  ///
  /// In en, this message translates to:
  /// **'No agent connected'**
  String get filesNoAgent;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get settingsAgent;

  /// No description provided for @settingsManageAgents.
  ///
  /// In en, this message translates to:
  /// **'Manage Agents'**
  String get settingsManageAgents;

  /// No description provided for @settingsManageAgentsSub.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or remove agent connections'**
  String get settingsManageAgentsSub;

  /// No description provided for @settingsProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get settingsProviders;

  /// No description provided for @settingsProvidersSub.
  ///
  /// In en, this message translates to:
  /// **'View available AI providers and capabilities'**
  String get settingsProvidersSub;

  /// No description provided for @settingsDefaultCli.
  ///
  /// In en, this message translates to:
  /// **'Default Provider'**
  String get settingsDefaultCli;

  /// No description provided for @settingsDefaultCliSub.
  ///
  /// In en, this message translates to:
  /// **'Default AI provider for new sessions'**
  String get settingsDefaultCliSub;

  /// No description provided for @settingsSession.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get settingsSession;

  /// No description provided for @settingsSessionOpenAtBottom.
  ///
  /// In en, this message translates to:
  /// **'Open sessions at the latest message'**
  String get settingsSessionOpenAtBottom;

  /// No description provided for @settingsSessionOpenAtBottomSub.
  ///
  /// In en, this message translates to:
  /// **'Show the last conversation when entering a session'**
  String get settingsSessionOpenAtBottomSub;

  /// No description provided for @settingsSessionTurnPageSize.
  ///
  /// In en, this message translates to:
  /// **'Session turn page size'**
  String get settingsSessionTurnPageSize;

  /// No description provided for @settingsSessionTurnPageSizeSub.
  ///
  /// In en, this message translates to:
  /// **'Control how many turns are fetched when opening a session or loading older messages'**
  String get settingsSessionTurnPageSizeSub;

  /// No description provided for @settingsSessionTurnPageSizeValue.
  ///
  /// In en, this message translates to:
  /// **'{count} turns per fetch'**
  String settingsSessionTurnPageSizeValue(int count);

  /// No description provided for @settingsShowAiCommitSessions.
  ///
  /// In en, this message translates to:
  /// **'Show AI commit sessions'**
  String get settingsShowAiCommitSessions;

  /// No description provided for @settingsShowAiCommitSessionsSub.
  ///
  /// In en, this message translates to:
  /// **'Include sessions created only for commit message generation'**
  String get settingsShowAiCommitSessionsSub;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeMode;

  /// No description provided for @settingsViewerFontSize.
  ///
  /// In en, this message translates to:
  /// **'File viewer font size'**
  String get settingsViewerFontSize;

  /// No description provided for @settingsViewerFontSizeSub.
  ///
  /// In en, this message translates to:
  /// **'Adjust font size in code, text, Markdown source and diff views'**
  String get settingsViewerFontSizeSub;

  /// No description provided for @viewerFontSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get viewerFontSizeSmall;

  /// No description provided for @viewerFontSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get viewerFontSizeMedium;

  /// No description provided for @viewerFontSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get viewerFontSizeLarge;

  /// No description provided for @viewerFontSizeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get viewerFontSizeReset;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsGit.
  ///
  /// In en, this message translates to:
  /// **'Git Operations'**
  String get settingsGit;

  /// No description provided for @settingsGitManage.
  ///
  /// In en, this message translates to:
  /// **'Git Management'**
  String get settingsGitManage;

  /// No description provided for @settingsGitManageSub.
  ///
  /// In en, this message translates to:
  /// **'Status, commit log, and branches'**
  String get settingsGitManageSub;

  /// No description provided for @settingsAiCommitModel.
  ///
  /// In en, this message translates to:
  /// **'AI commit model'**
  String get settingsAiCommitModel;

  /// No description provided for @settingsAiCommitModelSub.
  ///
  /// In en, this message translates to:
  /// **'Provider-specific model and reasoning effort for commit message generation'**
  String get settingsAiCommitModelSub;

  /// No description provided for @settingsCommitPush.
  ///
  /// In en, this message translates to:
  /// **'Commit & Push'**
  String get settingsCommitPush;

  /// No description provided for @settingsCommitPushSub.
  ///
  /// In en, this message translates to:
  /// **'Commit changes and push to remote'**
  String get settingsCommitPushSub;

  /// No description provided for @settingsCommitLog.
  ///
  /// In en, this message translates to:
  /// **'Commit Log'**
  String get settingsCommitLog;

  /// No description provided for @settingsCommitLogSub.
  ///
  /// In en, this message translates to:
  /// **'View commit history'**
  String get settingsCommitLogSub;

  /// No description provided for @settingsBranchesSub.
  ///
  /// In en, this message translates to:
  /// **'View and switch branches'**
  String get settingsBranchesSub;

  /// No description provided for @settingsCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsCache;

  /// No description provided for @settingsCacheManage.
  ///
  /// In en, this message translates to:
  /// **'Cache Management'**
  String get settingsCacheManage;

  /// No description provided for @settingsCacheManageSub.
  ///
  /// In en, this message translates to:
  /// **'View and clear cached data'**
  String get settingsCacheManageSub;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @noAgentConnected.
  ///
  /// In en, this message translates to:
  /// **'No agent connected'**
  String get noAgentConnected;

  /// No description provided for @untitledProject.
  ///
  /// In en, this message translates to:
  /// **'Untitled Project'**
  String get untitledProject;

  /// No description provided for @agentSelected.
  ///
  /// In en, this message translates to:
  /// **'Agent selected'**
  String get agentSelected;

  /// No description provided for @agentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Agent updated'**
  String get agentUpdated;

  /// No description provided for @agentConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected successfully'**
  String get agentConnected;

  /// No description provided for @agentRemoved.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" removed'**
  String agentRemoved(Object name);

  /// No description provided for @agentsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Agent'**
  String get agentsRemove;

  /// No description provided for @agentsRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? This will disconnect from this agent.'**
  String agentsRemoveConfirm(Object name);

  /// No description provided for @agentsRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get agentsRemoveAction;

  /// No description provided for @agentsEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Connect a local or remote agent to manage projects and sessions.'**
  String get agentsEmptySub;

  /// No description provided for @agentsSaveVerify.
  ///
  /// In en, this message translates to:
  /// **'Save & Verify'**
  String get agentsSaveVerify;

  /// No description provided for @projectsEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Add a workspace directory to create sessions, review changes, and browse files.'**
  String get projectsEmptySub;

  /// No description provided for @statusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get statusRunning;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get statusStopped;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get statusLost;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @sessionsEmptyYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionsEmptyYet;

  /// No description provided for @sessionsEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Start a new AI coding session'**
  String get sessionsEmptySub;

  /// No description provided for @sessionsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sessionsActive;

  /// No description provided for @sessionsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get sessionsArchived;

  /// No description provided for @sessionsArchivedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No archived sessions'**
  String get sessionsArchivedEmpty;

  /// No description provided for @sessionsArchivedEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Archived sessions will appear here'**
  String get sessionsArchivedEmptySub;

  /// No description provided for @sessionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sessionArchive;

  /// No description provided for @sessionUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get sessionUnarchive;

  /// No description provided for @sessionArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Archive failed'**
  String get sessionArchiveFailed;

  /// No description provided for @sessionUnarchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unarchive failed'**
  String get sessionUnarchiveFailed;

  /// No description provided for @sessionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get sessionDeleteTitle;

  /// No description provided for @sessionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This removes the local Codex history JSONL and cannot be undone.'**
  String sessionDeleteConfirm(Object title);

  /// No description provided for @sessionDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get sessionDeleteFailed;

  /// No description provided for @sessionPurposeAiCommit.
  ///
  /// In en, this message translates to:
  /// **'AI commit'**
  String get sessionPurposeAiCommit;

  /// No description provided for @sessionsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'{count} older sessions hidden. Tap to load.'**
  String sessionsLoadMore(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeDaysAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get chatSendFailed;

  /// No description provided for @chatStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Start failed'**
  String get chatStartFailed;

  /// No description provided for @chatInterruptFailed.
  ///
  /// In en, this message translates to:
  /// **'Interrupt failed'**
  String get chatInterruptFailed;

  /// No description provided for @chatStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Stop failed'**
  String get chatStopFailed;

  /// No description provided for @chatApprovalFailed.
  ///
  /// In en, this message translates to:
  /// **'Approval failed'**
  String get chatApprovalFailed;

  /// No description provided for @chatLoadSkillsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load skills'**
  String get chatLoadSkillsFailed;

  /// No description provided for @chatRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'Currently processing'**
  String get chatRunningTitle;

  /// No description provided for @chatRunningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to handle this new message'**
  String get chatRunningSubtitle;

  /// No description provided for @chatQueueMessage.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get chatQueueMessage;

  /// No description provided for @chatQueueMessageSub.
  ///
  /// In en, this message translates to:
  /// **'Send automatically after the current reply finishes.'**
  String get chatQueueMessageSub;

  /// No description provided for @chatInterruptAndSend.
  ///
  /// In en, this message translates to:
  /// **'Interrupt and send'**
  String get chatInterruptAndSend;

  /// No description provided for @chatInterruptAndSendSub.
  ///
  /// In en, this message translates to:
  /// **'Stop the current reply, then process this message immediately.'**
  String get chatInterruptAndSendSub;

  /// No description provided for @chatSessionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Session unavailable'**
  String get chatSessionLostTitle;

  /// No description provided for @chatSessionLostContent.
  ///
  /// In en, this message translates to:
  /// **'This session no longer exists on the server. It may have been removed after the server restarted. Create a new session to continue.'**
  String get chatSessionLostContent;

  /// No description provided for @chatInterruptSent.
  ///
  /// In en, this message translates to:
  /// **'Interrupt request sent'**
  String get chatInterruptSent;

  /// No description provided for @chatStopSession.
  ///
  /// In en, this message translates to:
  /// **'Stop session'**
  String get chatStopSession;

  /// No description provided for @chatStopConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop this session?'**
  String get chatStopConfirm;

  /// No description provided for @chatSessionStopped.
  ///
  /// In en, this message translates to:
  /// **'Session stopped'**
  String get chatSessionStopped;

  /// No description provided for @chatNoSkills.
  ///
  /// In en, this message translates to:
  /// **'No skills available'**
  String get chatNoSkills;

  /// No description provided for @chatMissingProject.
  ///
  /// In en, this message translates to:
  /// **'Current session is missing project information'**
  String get chatMissingProject;

  /// No description provided for @chatRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get chatRefresh;

  /// No description provided for @chatSettings.
  ///
  /// In en, this message translates to:
  /// **'Session settings'**
  String get chatSettings;

  /// No description provided for @chatSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Session settings'**
  String get chatSettingsTitle;

  /// No description provided for @chatSettingsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chatSettingsModel;

  /// No description provided for @chatSettingsEffort.
  ///
  /// In en, this message translates to:
  /// **'Reasoning effort'**
  String get chatSettingsEffort;

  /// No description provided for @chatSettingsApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval policy'**
  String get chatSettingsApproval;

  /// No description provided for @chatSettingsSandbox.
  ///
  /// In en, this message translates to:
  /// **'Sandbox mode'**
  String get chatSettingsSandbox;

  /// No description provided for @chatSettingsApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get chatSettingsApply;

  /// No description provided for @chatSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Client-only override applied to your next send; the server does not persist these.'**
  String get chatSettingsHint;

  /// No description provided for @chatCreateNewSession.
  ///
  /// In en, this message translates to:
  /// **'Create new session'**
  String get chatCreateNewSession;

  /// No description provided for @chatSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get chatSessionEnded;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoMessages;

  /// No description provided for @chatSessionNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Session not started'**
  String get chatSessionNotStarted;

  /// No description provided for @chatStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get chatStarting;

  /// No description provided for @chatStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get chatStartSession;

  /// No description provided for @chatNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get chatNewSession;

  /// No description provided for @chatPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get chatPlan;

  /// No description provided for @chatReasoningSummary.
  ///
  /// In en, this message translates to:
  /// **'Reasoning summary'**
  String get chatReasoningSummary;

  /// No description provided for @chatDiffSummary.
  ///
  /// In en, this message translates to:
  /// **'Change summary'**
  String get chatDiffSummary;

  /// No description provided for @chatCommandOutput.
  ///
  /// In en, this message translates to:
  /// **'Command output'**
  String get chatCommandOutput;

  /// No description provided for @chatFileChangeOutput.
  ///
  /// In en, this message translates to:
  /// **'File change output'**
  String get chatFileChangeOutput;

  /// No description provided for @chatCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get chatCommand;

  /// No description provided for @chatFileChange.
  ///
  /// In en, this message translates to:
  /// **'File change'**
  String get chatFileChange;

  /// No description provided for @chatReadFile.
  ///
  /// In en, this message translates to:
  /// **'Read file'**
  String get chatReadFile;

  /// No description provided for @chatTurnStarted.
  ///
  /// In en, this message translates to:
  /// **'Started processing...'**
  String get chatTurnStarted;

  /// No description provided for @chatTurnCompleted.
  ///
  /// In en, this message translates to:
  /// **'Processing completed'**
  String get chatTurnCompleted;

  /// No description provided for @chatTurnFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get chatTurnFailed;

  /// No description provided for @chatApprovalResolved.
  ///
  /// In en, this message translates to:
  /// **'Approval handled'**
  String get chatApprovalResolved;

  /// No description provided for @chatExited.
  ///
  /// In en, this message translates to:
  /// **'Session exited (code: {code})'**
  String chatExited(Object code);

  /// No description provided for @chatPlanUpdated.
  ///
  /// In en, this message translates to:
  /// **'Plan updated'**
  String get chatPlanUpdated;

  /// No description provided for @chatReasoningUpdated.
  ///
  /// In en, this message translates to:
  /// **'Reasoning summary updated'**
  String get chatReasoningUpdated;

  /// No description provided for @chatFileUpdated.
  ///
  /// In en, this message translates to:
  /// **'File updated'**
  String get chatFileUpdated;

  /// No description provided for @chatFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String chatFileCount(int count);

  /// No description provided for @chatRunningQueued.
  ///
  /// In en, this message translates to:
  /// **'Generating reply, {count} messages queued'**
  String chatRunningQueued(int count);

  /// No description provided for @chatRunningHint.
  ///
  /// In en, this message translates to:
  /// **'Generating reply. Send again to queue or interrupt.'**
  String get chatRunningHint;

  /// No description provided for @chatQueuedInputs.
  ///
  /// In en, this message translates to:
  /// **'{count} messages queued'**
  String chatQueuedInputs(int count);

  /// No description provided for @chatTemplatesTooltip.
  ///
  /// In en, this message translates to:
  /// **'History and templates'**
  String get chatTemplatesTooltip;

  /// No description provided for @chatSkillsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Use skill'**
  String get chatSkillsTooltip;

  /// No description provided for @chatFilesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reference workspace path'**
  String get chatFilesTooltip;

  /// No description provided for @chatChooseSkill.
  ///
  /// In en, this message translates to:
  /// **'Choose skill'**
  String get chatChooseSkill;

  /// No description provided for @chatChooseWorkspaceFile.
  ///
  /// In en, this message translates to:
  /// **'Choose workspace file or folder'**
  String get chatChooseWorkspaceFile;

  /// No description provided for @chatContextCompacted.
  ///
  /// In en, this message translates to:
  /// **'Conversation compressed'**
  String get chatContextCompacted;

  /// No description provided for @chatLoadOlderMessages.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get chatLoadOlderMessages;

  /// No description provided for @chatCollapsedEvents.
  ///
  /// In en, this message translates to:
  /// **'{count} older messages hidden'**
  String chatCollapsedEvents(int count);

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @approvalRequired.
  ///
  /// In en, this message translates to:
  /// **'Approval required'**
  String get approvalRequired;

  /// No description provided for @approvalUnknownAction.
  ///
  /// In en, this message translates to:
  /// **'Unknown operation'**
  String get approvalUnknownAction;

  /// No description provided for @approvalAllowSession.
  ///
  /// In en, this message translates to:
  /// **'Allow for session'**
  String get approvalAllowSession;

  /// No description provided for @templatesSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get templatesSaveAs;

  /// No description provided for @templatesNameHint.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templatesNameHint;

  /// No description provided for @templatesRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent messages'**
  String get templatesRecent;

  /// No description provided for @templatesSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved templates'**
  String get templatesSaved;

  /// No description provided for @templatesNoRecent.
  ///
  /// In en, this message translates to:
  /// **'No recent messages'**
  String get templatesNoRecent;

  /// No description provided for @templatesNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No saved templates'**
  String get templatesNoSaved;

  /// No description provided for @templatesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get templatesDelete;

  /// No description provided for @providersTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get providersTitle;

  /// No description provided for @providersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No providers found'**
  String get providersEmpty;

  /// No description provided for @providersAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get providersAvailable;

  /// No description provided for @providersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get providersUnavailable;

  /// No description provided for @providersNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get providersNotAvailable;

  /// No description provided for @providersBinary.
  ///
  /// In en, this message translates to:
  /// **'Binary'**
  String get providersBinary;

  /// No description provided for @providersMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get providersMode;

  /// No description provided for @providersCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get providersCapabilities;

  /// No description provided for @providersUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get providersUnknown;

  /// No description provided for @capabilityResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get capabilityResume;

  /// No description provided for @capabilityFork.
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get capabilityFork;

  /// No description provided for @capabilitySteer.
  ///
  /// In en, this message translates to:
  /// **'Steer'**
  String get capabilitySteer;

  /// No description provided for @capabilityInterrupt.
  ///
  /// In en, this message translates to:
  /// **'Interrupt'**
  String get capabilityInterrupt;

  /// No description provided for @capabilityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get capabilityCompact;

  /// No description provided for @capabilityRollback.
  ///
  /// In en, this message translates to:
  /// **'Rollback'**
  String get capabilityRollback;

  /// No description provided for @capabilityApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get capabilityApproval;

  /// No description provided for @capabilityFileSystem.
  ///
  /// In en, this message translates to:
  /// **'File System'**
  String get capabilityFileSystem;

  /// No description provided for @capabilityMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get capabilityMcp;

  /// No description provided for @capabilityPty.
  ///
  /// In en, this message translates to:
  /// **'PTY'**
  String get capabilityPty;

  /// No description provided for @capabilityStreaming.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get capabilityStreaming;

  /// No description provided for @capabilityStructuredOutput.
  ///
  /// In en, this message translates to:
  /// **'Structured Output'**
  String get capabilityStructuredOutput;

  /// No description provided for @cacheClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get cacheClear;

  /// No description provided for @cacheClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get cacheClearAll;

  /// No description provided for @cacheClearAllCaches.
  ///
  /// In en, this message translates to:
  /// **'Clear All Caches'**
  String get cacheClearAllCaches;

  /// No description provided for @cacheClearAllDisplayCaches.
  ///
  /// In en, this message translates to:
  /// **'Clear All Display Caches'**
  String get cacheClearAllDisplayCaches;

  /// No description provided for @cacheClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'This removes local display caches only. Provider history, Git state, and files remain the source of truth.'**
  String get cacheClearConfirm;

  /// No description provided for @cacheGitDisplay.
  ///
  /// In en, this message translates to:
  /// **'Git Display Cache'**
  String get cacheGitDisplay;

  /// No description provided for @cacheFileDisplay.
  ///
  /// In en, this message translates to:
  /// **'File Display Cache'**
  String get cacheFileDisplay;

  /// No description provided for @cacheSessionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Session Display Cache'**
  String get cacheSessionDisplay;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'{name} cache cleared'**
  String cacheCleared(Object name);

  /// No description provided for @cacheEntries.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String cacheEntries(int count);

  /// No description provided for @gitStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get gitStatus;

  /// No description provided for @gitLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get gitLog;

  /// No description provided for @gitPull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get gitPull;

  /// No description provided for @gitRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get gitRoot;

  /// No description provided for @gitPullFailed.
  ///
  /// In en, this message translates to:
  /// **'Pull failed'**
  String get gitPullFailed;

  /// No description provided for @gitPullSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Pull successful'**
  String get gitPullSuccessful;

  /// No description provided for @gitPushSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Push successful'**
  String get gitPushSuccessful;

  /// No description provided for @gitStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Stage failed'**
  String get gitStageFailed;

  /// No description provided for @gitUnstageFailed.
  ///
  /// In en, this message translates to:
  /// **'Unstage failed'**
  String get gitUnstageFailed;

  /// No description provided for @gitDiscardFailed.
  ///
  /// In en, this message translates to:
  /// **'Discard failed'**
  String get gitDiscardFailed;

  /// No description provided for @gitDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get gitDiscardChanges;

  /// No description provided for @gitDiscardChangesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard changes in {count} files? This cannot be undone.'**
  String gitDiscardChangesConfirm(int count);

  /// No description provided for @gitForcePush.
  ///
  /// In en, this message translates to:
  /// **'Force Push'**
  String get gitForcePush;

  /// No description provided for @gitForcePushConfirm.
  ///
  /// In en, this message translates to:
  /// **'Force push will overwrite remote history. Continue?'**
  String get gitForcePushConfirm;

  /// No description provided for @gitStaged.
  ///
  /// In en, this message translates to:
  /// **'Staged'**
  String get gitStaged;

  /// No description provided for @gitUnstaged.
  ///
  /// In en, this message translates to:
  /// **'Unstaged'**
  String get gitUnstaged;

  /// No description provided for @gitWorkingTreeClean.
  ///
  /// In en, this message translates to:
  /// **'Working tree clean'**
  String get gitWorkingTreeClean;

  /// No description provided for @gitNoStagedFiles.
  ///
  /// In en, this message translates to:
  /// **'No staged files'**
  String get gitNoStagedFiles;

  /// No description provided for @gitNoUnstagedFiles.
  ///
  /// In en, this message translates to:
  /// **'No unstaged files'**
  String get gitNoUnstagedFiles;

  /// No description provided for @gitNoFilesChanged.
  ///
  /// In en, this message translates to:
  /// **'No files changed'**
  String get gitNoFilesChanged;

  /// No description provided for @gitBinaryFile.
  ///
  /// In en, this message translates to:
  /// **'Binary file'**
  String get gitBinaryFile;

  /// No description provided for @gitBinaryFileDiffUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Binary file - cannot display diff'**
  String get gitBinaryFileDiffUnavailable;

  /// No description provided for @gitNoTextChanges.
  ///
  /// In en, this message translates to:
  /// **'No text changes'**
  String get gitNoTextChanges;

  /// No description provided for @gitCannotDisplayImage.
  ///
  /// In en, this message translates to:
  /// **'Cannot display image - no file API'**
  String get gitCannotDisplayImage;

  /// No description provided for @gitImageDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image data not available'**
  String get gitImageDataUnavailable;

  /// No description provided for @gitLoadImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get gitLoadImageFailed;

  /// No description provided for @gitLoadDiffFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Diff'**
  String get gitLoadDiffFailed;

  /// No description provided for @gitAiMessageGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI message generated'**
  String get gitAiMessageGenerated;

  /// No description provided for @gitAiReturnedEmpty.
  ///
  /// In en, this message translates to:
  /// **'AI returned empty response'**
  String get gitAiReturnedEmpty;

  /// No description provided for @gitAiSuggestionFailed.
  ///
  /// In en, this message translates to:
  /// **'AI suggestion failed'**
  String get gitAiSuggestionFailed;

  /// No description provided for @gitCommitMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Commit message is required'**
  String get gitCommitMessageRequired;

  /// No description provided for @gitCommitSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Commit successful'**
  String get gitCommitSuccessful;

  /// No description provided for @gitCommitMessageHint.
  ///
  /// In en, this message translates to:
  /// **'feat: describe your changes...'**
  String get gitCommitMessageHint;

  /// No description provided for @gitAiSuggest.
  ///
  /// In en, this message translates to:
  /// **'AI suggest'**
  String get gitAiSuggest;

  /// No description provided for @gitGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get gitGenerating;

  /// No description provided for @gitAiGenerateMessage.
  ///
  /// In en, this message translates to:
  /// **'AI Generate Message'**
  String get gitAiGenerateMessage;

  /// No description provided for @gitStageAllChanges.
  ///
  /// In en, this message translates to:
  /// **'Stage all changes (-a)'**
  String get gitStageAllChanges;

  /// No description provided for @wrap.
  ///
  /// In en, this message translates to:
  /// **'Wrap'**
  String get wrap;

  /// No description provided for @noWrap.
  ///
  /// In en, this message translates to:
  /// **'No wrap'**
  String get noWrap;

  /// No description provided for @enableWrap.
  ///
  /// In en, this message translates to:
  /// **'Enable wrap'**
  String get enableWrap;

  /// No description provided for @disableWrap.
  ///
  /// In en, this message translates to:
  /// **'Disable wrap'**
  String get disableWrap;

  /// No description provided for @viewerSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get viewerSource;

  /// No description provided for @viewerRender.
  ///
  /// In en, this message translates to:
  /// **'Render'**
  String get viewerRender;

  /// No description provided for @viewerSourceMode.
  ///
  /// In en, this message translates to:
  /// **'Source mode'**
  String get viewerSourceMode;

  /// No description provided for @viewerRenderMode.
  ///
  /// In en, this message translates to:
  /// **'Render mode'**
  String get viewerRenderMode;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @filesReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Read failed'**
  String get filesReadFailed;

  /// No description provided for @filesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get filesLoadFailed;

  /// No description provided for @filesPreviewTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large to preview'**
  String get filesPreviewTooLarge;

  /// No description provided for @filesPreviewBinaryUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Binary file cannot be previewed'**
  String get filesPreviewBinaryUnsupported;

  /// No description provided for @filesNoSubdirectories.
  ///
  /// In en, this message translates to:
  /// **'No subdirectories'**
  String get filesNoSubdirectories;

  /// No description provided for @filesSelectPath.
  ///
  /// In en, this message translates to:
  /// **'Select: {path}'**
  String filesSelectPath(Object path);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
