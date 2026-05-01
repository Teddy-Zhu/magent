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
