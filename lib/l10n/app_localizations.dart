import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application name shown in the app bar and task switcher
  ///
  /// In en, this message translates to:
  /// **'Tomera'**
  String get appTitle;

  /// No description provided for @tabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get tabWork;

  /// No description provided for @tabTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tabTasks;

  /// No description provided for @tabNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tabNotes;

  /// No description provided for @tabWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get tabWorkspaces;

  /// No description provided for @tabContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get tabContacts;

  /// No description provided for @tabFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get tabFinance;

  /// Workspace filter option that shows data from every workspace
  ///
  /// In en, this message translates to:
  /// **'All workspaces'**
  String get allWorkspaces;

  /// Compact label for the all-workspaces filter pill next to a screen title
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allWorkspacesShort;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @unableToLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this yet'**
  String get unableToLoadTitle;

  /// No description provided for @unableToLoadBody.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment.'**
  String get unableToLoadBody;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAdd;

  /// No description provided for @quickAddChooseWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Choose a workspace to continue.'**
  String get quickAddChooseWorkspace;

  /// No description provided for @moduleUnavailableInWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Not available in this workspace'**
  String get moduleUnavailableInWorkspace;

  /// No description provided for @moduleDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'This module is turned off'**
  String get moduleDisabledTitle;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your first workspace'**
  String get setupTitle;

  /// No description provided for @setupBody.
  ///
  /// In en, this message translates to:
  /// **'A workspace keeps related tasks, events, notes, contacts, and billable work together.'**
  String get setupBody;

  /// No description provided for @createWorkspaceAction.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get createWorkspaceAction;

  /// No description provided for @tryDemoAction.
  ///
  /// In en, this message translates to:
  /// **'Try an example workspace'**
  String get tryDemoAction;

  /// No description provided for @demoDataNote.
  ///
  /// In en, this message translates to:
  /// **'Example data is optional and can be removed from Today.'**
  String get demoDataNote;

  /// No description provided for @checklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up Tomera'**
  String get checklistTitle;

  /// No description provided for @checklistProject.
  ///
  /// In en, this message translates to:
  /// **'Create your first project'**
  String get checklistProject;

  /// No description provided for @checklistTask.
  ///
  /// In en, this message translates to:
  /// **'Plan your first task'**
  String get checklistTask;

  /// No description provided for @checklistContact.
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get checklistContact;

  /// No description provided for @checklistProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} complete'**
  String checklistProgress(int completed, int total);

  /// No description provided for @dismissAction.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissAction;

  /// No description provided for @removeDemoAction.
  ///
  /// In en, this message translates to:
  /// **'Remove example data'**
  String get removeDemoAction;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Your unsaved changes will be lost.'**
  String get discardChangesBody;

  /// No description provided for @keepEditingAction.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditingAction;

  /// No description provided for @discardChangesAction.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChangesAction;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @parentRecordLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent record'**
  String get parentRecordLabel;

  /// No description provided for @noParentRecord.
  ///
  /// In en, this message translates to:
  /// **'No parent'**
  String get noParentRecord;

  /// No description provided for @referencesLabel.
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get referencesLabel;

  /// No description provided for @addReferenceAction.
  ///
  /// In en, this message translates to:
  /// **'Add reference'**
  String get addReferenceAction;

  /// No description provided for @createTaskFromSelectionAction.
  ///
  /// In en, this message translates to:
  /// **'Create task from selection'**
  String get createTaskFromSelectionAction;

  /// No description provided for @selectNoteTextFirst.
  ///
  /// In en, this message translates to:
  /// **'Select some note text first.'**
  String get selectNoteTextFirst;

  /// No description provided for @workspaceRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace rate (€)'**
  String get workspaceRateLabel;

  /// No description provided for @activityTimeline.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTimeline;

  /// No description provided for @activityEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get activityEvent;

  /// No description provided for @activityCompletedTask.
  ///
  /// In en, this message translates to:
  /// **'Completed task'**
  String get activityCompletedTask;

  /// No description provided for @activityNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get activityNote;

  /// No description provided for @activityTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer session'**
  String get activityTimer;

  /// No description provided for @activityBillable.
  ///
  /// In en, this message translates to:
  /// **'Billable'**
  String get activityBillable;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @taskStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Task status updated.'**
  String get taskStatusChanged;

  /// No description provided for @billableStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Billable status updated.'**
  String get billableStatusChanged;

  /// No description provided for @eventMoved.
  ///
  /// In en, this message translates to:
  /// **'Event time updated.'**
  String get eventMoved;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted.'**
  String get taskDeleted;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted.'**
  String get noteDeleted;

  /// No description provided for @eventDeleted.
  ///
  /// In en, this message translates to:
  /// **'Event deleted.'**
  String get eventDeleted;

  /// No description provided for @billableDeleted.
  ///
  /// In en, this message translates to:
  /// **'Billable item deleted.'**
  String get billableDeleted;

  /// No description provided for @tomorrowButton.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowButton;

  /// No description provided for @nextMondayButton.
  ///
  /// In en, this message translates to:
  /// **'Next Monday'**
  String get nextMondayButton;

  /// No description provided for @filtersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersLabel;

  /// No description provided for @todayActiveTimer.
  ///
  /// In en, this message translates to:
  /// **'Active timer'**
  String get todayActiveTimer;

  /// No description provided for @todaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get todaySchedule;

  /// No description provided for @todayTasks.
  ///
  /// In en, this message translates to:
  /// **'Due tasks'**
  String get todayTasks;

  /// No description provided for @todayUnbilled.
  ///
  /// In en, this message translates to:
  /// **'Unbilled'**
  String get todayUnbilled;

  /// No description provided for @todayUnbilledTime.
  ///
  /// In en, this message translates to:
  /// **'Unbilled time'**
  String get todayUnbilledTime;

  /// No description provided for @todayRecentNotes.
  ///
  /// In en, this message translates to:
  /// **'Recent notes'**
  String get todayRecentNotes;

  /// No description provided for @todayNoActiveTimer.
  ///
  /// In en, this message translates to:
  /// **'No timer is running.'**
  String get todayNoActiveTimer;

  /// No description provided for @todayNoEvent.
  ///
  /// In en, this message translates to:
  /// **'Nothing else is scheduled today.'**
  String get todayNoEvent;

  /// No description provided for @todayNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No overdue tasks or tasks due today.'**
  String get todayNoTasks;

  /// No description provided for @todayNoUnbilled.
  ///
  /// In en, this message translates to:
  /// **'No unbilled work in this view.'**
  String get todayNoUnbilled;

  /// No description provided for @todayNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No recent notes in this view.'**
  String get todayNoNotes;

  /// No description provided for @todayOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get todayOngoing;

  /// No description provided for @todayNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get todayNext;

  /// No description provided for @todayHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String todayHoursMinutes(int hours, int minutes);

  /// No description provided for @todayMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String todayMinutes(int minutes);

  /// No description provided for @newWorkspace.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get newWorkspace;

  /// No description provided for @editWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Edit workspace'**
  String get editWorkspace;

  /// No description provided for @workspaceName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspaceName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// No description provided for @iconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get iconLabel;

  /// No description provided for @modulesLabel.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get modulesLabel;

  /// No description provided for @moduleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get moduleCalendar;

  /// No description provided for @moduleTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get moduleTasks;

  /// No description provided for @moduleNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get moduleNotes;

  /// No description provided for @moduleContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get moduleContacts;

  /// No description provided for @moduleFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get moduleFinance;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTask;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskTitle;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get titleRequired;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @workspaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceLabel;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priorityLabel;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @dueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDateLabel;

  /// No description provided for @dueTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get dueTimeLabel;

  /// No description provided for @clearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get clearDueDate;

  /// No description provided for @reminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderLabel;

  /// No description provided for @reminderDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder date'**
  String get reminderDateLabel;

  /// No description provided for @clearReminder.
  ///
  /// In en, this message translates to:
  /// **'Clear reminder'**
  String get clearReminder;

  /// No description provided for @remindNone.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get remindNone;

  /// No description provided for @remindAtStart.
  ///
  /// In en, this message translates to:
  /// **'At start'**
  String get remindAtStart;

  /// No description provided for @remind15m.
  ///
  /// In en, this message translates to:
  /// **'15 minutes before'**
  String get remind15m;

  /// No description provided for @remind1h.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get remind1h;

  /// No description provided for @remind1d.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get remind1d;

  /// No description provided for @groupByStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get groupByStatus;

  /// No description provided for @groupByDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get groupByDueDate;

  /// No description provided for @filterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get filterOverdue;

  /// No description provided for @dueSectionOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dueSectionOverdue;

  /// No description provided for @dueSectionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dueSectionToday;

  /// No description provided for @dueSectionThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get dueSectionThisWeek;

  /// No description provided for @dueSectionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get dueSectionLater;

  /// No description provided for @dueSectionNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get dueSectionNoDueDate;

  /// No description provided for @emptyTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get emptyTasksTitle;

  /// No description provided for @emptyTasksBody.
  ///
  /// In en, this message translates to:
  /// **'Capture the next thing you need to do.'**
  String get emptyTasksBody;

  /// No description provided for @tasksModuleDisabled.
  ///
  /// In en, this message translates to:
  /// **'The tasks module is disabled in this workspace.'**
  String get tasksModuleDisabled;

  /// No description provided for @deleteTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get deleteTaskTitle;

  /// No description provided for @deleteTaskBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed from your lists.'**
  String deleteTaskBody(String title);

  /// No description provided for @createWorkspaceFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a workspace first.'**
  String get createWorkspaceFirst;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export.'**
  String get nothingToExport;

  /// No description provided for @itemsTab.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsTab;

  /// No description provided for @summaryTab.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTab;

  /// No description provided for @overviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overviewLabel;

  /// No description provided for @byWorkspaceLabel.
  ///
  /// In en, this message translates to:
  /// **'By workspace'**
  String get byWorkspaceLabel;

  /// No description provided for @byContactLabel.
  ///
  /// In en, this message translates to:
  /// **'By contact'**
  String get byContactLabel;

  /// No description provided for @hoursThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Hours this month'**
  String get hoursThisMonth;

  /// No description provided for @invoicedUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Invoiced, unpaid'**
  String get invoicedUnpaid;

  /// No description provided for @paidThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Paid this month'**
  String get paidThisMonth;

  /// No description provided for @thisMonthButton.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonthButton;

  /// No description provided for @workTimer.
  ///
  /// In en, this message translates to:
  /// **'Work timer'**
  String get workTimer;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get startTimer;

  /// No description provided for @stopTimer.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopTimer;

  /// No description provided for @timerRunning.
  ///
  /// In en, this message translates to:
  /// **'Timer running'**
  String get timerRunning;

  /// No description provided for @timerSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer session'**
  String get timerSessionTitle;

  /// No description provided for @timerSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'This timer session is no longer available.'**
  String get timerSessionNotFound;

  /// No description provided for @removeUnconvertedTime.
  ///
  /// In en, this message translates to:
  /// **'Remove unconverted time'**
  String get removeUnconvertedTime;

  /// No description provided for @removeTimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove unconverted time?'**
  String get removeTimerTitle;

  /// No description provided for @removeTimerBody.
  ///
  /// In en, this message translates to:
  /// **'This timer session will be removed from your lists.'**
  String get removeTimerBody;

  /// No description provided for @timerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Unconverted time removed.'**
  String get timerRemoved;

  /// No description provided for @timerRemovalFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t remove this timer. Try again.'**
  String get timerRemovalFailed;

  /// No description provided for @timerAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A timer is already running.'**
  String get timerAlreadyRunning;

  /// No description provided for @unconvertedTime.
  ///
  /// In en, this message translates to:
  /// **'Unconverted time'**
  String get unconvertedTime;

  /// No description provided for @unconvertedTimeBody.
  ///
  /// In en, this message translates to:
  /// **'Stopped timers stay here until they become billable items.'**
  String get unconvertedTimeBody;

  /// No description provided for @convertToBillable.
  ///
  /// In en, this message translates to:
  /// **'Convert to billable'**
  String get convertToBillable;

  /// No description provided for @timerConverted.
  ///
  /// In en, this message translates to:
  /// **'Timer converted to a billable item.'**
  String get timerConverted;

  /// No description provided for @timerConversionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t convert this timer. Try again.'**
  String get timerConversionFailed;

  /// No description provided for @repeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatLabel;

  /// No description provided for @doesNotRepeat.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get doesNotRepeat;

  /// No description provided for @recurrenceFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get recurrenceFrequencyLabel;

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get recurrenceYearly;

  /// No description provided for @repeatEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get repeatEveryLabel;

  /// No description provided for @intervalUnitDays.
  ///
  /// In en, this message translates to:
  /// **'day(s)'**
  String get intervalUnitDays;

  /// No description provided for @intervalUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'week(s)'**
  String get intervalUnitWeeks;

  /// No description provided for @intervalUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'month(s)'**
  String get intervalUnitMonths;

  /// No description provided for @intervalUnitYears.
  ///
  /// In en, this message translates to:
  /// **'year(s)'**
  String get intervalUnitYears;

  /// No description provided for @repeatOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get repeatOnLabel;

  /// No description provided for @recurrenceEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get recurrenceEndsLabel;

  /// No description provided for @recurrenceNeverEnds.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get recurrenceNeverEnds;

  /// No description provided for @recurrenceOnDate.
  ///
  /// In en, this message translates to:
  /// **'On date'**
  String get recurrenceOnDate;

  /// No description provided for @recurrenceAfterCount.
  ///
  /// In en, this message translates to:
  /// **'After count'**
  String get recurrenceAfterCount;

  /// No description provided for @inclusiveEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Inclusive end date'**
  String get inclusiveEndDateLabel;

  /// No description provided for @occurrenceCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get occurrenceCountLabel;

  /// No description provided for @repeatAnchorLabel.
  ///
  /// In en, this message translates to:
  /// **'Next task advances'**
  String get repeatAnchorLabel;

  /// No description provided for @repeatFromSchedule.
  ///
  /// In en, this message translates to:
  /// **'From prior due date'**
  String get repeatFromSchedule;

  /// No description provided for @repeatFromCompletion.
  ///
  /// In en, this message translates to:
  /// **'From completion time'**
  String get repeatFromCompletion;

  /// No description provided for @recurrenceRequiresDueDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a due date before enabling repeat.'**
  String get recurrenceRequiresDueDate;

  /// No description provided for @recurrenceReminderBeforeDue.
  ///
  /// In en, this message translates to:
  /// **'A repeating task reminder must be at or before its due time.'**
  String get recurrenceReminderBeforeDue;

  /// No description provided for @recurringSeriesContext.
  ///
  /// In en, this message translates to:
  /// **'Part of a recurring series'**
  String get recurringSeriesContext;

  /// No description provided for @editRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring event'**
  String get editRecurringTitle;

  /// No description provided for @editThisOccurrence.
  ///
  /// In en, this message translates to:
  /// **'This occurrence'**
  String get editThisOccurrence;

  /// No description provided for @editCurrentAndFuture.
  ///
  /// In en, this message translates to:
  /// **'This and future occurrences'**
  String get editCurrentAndFuture;

  /// No description provided for @deleteRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recurring event'**
  String get deleteRecurringTitle;

  /// No description provided for @deleteThisOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Delete this occurrence'**
  String get deleteThisOccurrence;

  /// No description provided for @deleteCurrentAndFuture.
  ///
  /// In en, this message translates to:
  /// **'Delete this and future occurrences'**
  String get deleteCurrentAndFuture;

  /// No description provided for @invalidInterval.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number greater than zero'**
  String get invalidInterval;

  /// No description provided for @invalidOccurrenceCount.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one occurrence'**
  String get invalidOccurrenceCount;

  /// No description provided for @recurrenceEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The repeat end must include at least one occurrence.'**
  String get recurrenceEndBeforeStart;

  /// No description provided for @recurrenceTimezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone: {timezone}'**
  String recurrenceTimezone(String timezone);

  /// No description provided for @cannotReopenRecurringTask.
  ///
  /// In en, this message translates to:
  /// **'This task can’t be reopened because its next occurrence has already progressed.'**
  String get cannotReopenRecurringTask;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
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

  /// No description provided for @roundingLabel.
  ///
  /// In en, this message translates to:
  /// **'Timer duration rounding'**
  String get roundingLabel;

  /// No description provided for @weekStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get weekStartLabel;

  /// No description provided for @weekStartMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekStartMonday;

  /// No description provided for @weekStartSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekStartSunday;

  /// No description provided for @timeFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get timeFormatLabel;

  /// No description provided for @timeFormatSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get timeFormatSystem;

  /// No description provided for @timeFormat12.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get timeFormat12;

  /// No description provided for @timeFormat24.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get timeFormat24;

  /// No description provided for @roundingNone.
  ///
  /// In en, this message translates to:
  /// **'No rounding'**
  String get roundingNone;

  /// No description provided for @roundingOption.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes, round up'**
  String roundingOption(int minutes);

  /// No description provided for @newBillable.
  ///
  /// In en, this message translates to:
  /// **'New billable item'**
  String get newBillable;

  /// No description provided for @editBillable.
  ///
  /// In en, this message translates to:
  /// **'Edit billable item'**
  String get editBillable;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @typeHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get typeHourly;

  /// No description provided for @typeFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get typeFixed;

  /// No description provided for @rateLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate (€/h)'**
  String get rateLabel;

  /// No description provided for @durationMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get durationMinutesLabel;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (€)'**
  String get amountLabel;

  /// No description provided for @currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyLabel;

  /// No description provided for @billableStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get billableStatusLabel;

  /// No description provided for @statusUnbilled.
  ///
  /// In en, this message translates to:
  /// **'Unbilled'**
  String get statusUnbilled;

  /// No description provided for @statusInvoiced.
  ///
  /// In en, this message translates to:
  /// **'Invoiced'**
  String get statusInvoiced;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @emptyBillablesTitle.
  ///
  /// In en, this message translates to:
  /// **'No billable items'**
  String get emptyBillablesTitle;

  /// No description provided for @emptyBillablesBody.
  ///
  /// In en, this message translates to:
  /// **'Track time or a fixed amount you can bill later.'**
  String get emptyBillablesBody;

  /// No description provided for @financeModuleDisabled.
  ///
  /// In en, this message translates to:
  /// **'The finance module is disabled in this workspace.'**
  String get financeModuleDisabled;

  /// No description provided for @deleteBillableTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete billable item?'**
  String get deleteBillableTitle;

  /// No description provided for @deleteBillableBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed from your lists.'**
  String deleteBillableBody(String title);

  /// No description provided for @financialSummary.
  ///
  /// In en, this message translates to:
  /// **'Financial summary'**
  String get financialSummary;

  /// No description provided for @invalidDuration.
  ///
  /// In en, this message translates to:
  /// **'Enter minutes as a whole number'**
  String get invalidDuration;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @addInstances.
  ///
  /// In en, this message translates to:
  /// **'Add instances'**
  String get addInstances;

  /// No description provided for @defaultTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Default time'**
  String get defaultTimeLabel;

  /// No description provided for @applyToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply to all'**
  String get applyToAll;

  /// No description provided for @repeatWeeklyOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat weekly on'**
  String get repeatWeeklyOnLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @untilLabel.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get untilLabel;

  /// No description provided for @generateDates.
  ///
  /// In en, this message translates to:
  /// **'Generate dates'**
  String get generateDates;

  /// No description provided for @pickDatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Or pick dates manually'**
  String get pickDatesLabel;

  /// No description provided for @addSelectedDates.
  ///
  /// In en, this message translates to:
  /// **'Add selected dates'**
  String get addSelectedDates;

  /// No description provided for @instancesCount.
  ///
  /// In en, this message translates to:
  /// **'Instances ({count})'**
  String instancesCount(int count);

  /// No description provided for @addSingleDate.
  ///
  /// In en, this message translates to:
  /// **'Add date'**
  String get addSingleDate;

  /// No description provided for @noInstancesYet.
  ///
  /// In en, this message translates to:
  /// **'No dates yet — generate from a pattern or pick dates above.'**
  String get noInstancesYet;

  /// No description provided for @createInstances.
  ///
  /// In en, this message translates to:
  /// **'Create {count} events'**
  String createInstances(int count);

  /// No description provided for @instanceConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count} of the new events overlap existing ones:'**
  String instanceConflicts(int count);

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @editProject.
  ///
  /// In en, this message translates to:
  /// **'Edit project'**
  String get editProject;

  /// No description provided for @projectLabel.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectLabel;

  /// No description provided for @noProject.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noProject;

  /// No description provided for @archivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedLabel;

  /// No description provided for @showArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get showArchived;

  /// No description provided for @useWorkspaceColor.
  ///
  /// In en, this message translates to:
  /// **'Workspace color'**
  String get useWorkspaceColor;

  /// No description provided for @emptyProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects'**
  String get emptyProjectsTitle;

  /// No description provided for @emptyProjectsBody.
  ///
  /// In en, this message translates to:
  /// **'Group a course, a client gig or any recurring work with the + button.'**
  String get emptyProjectsBody;

  /// No description provided for @deleteProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete project?'**
  String get deleteProjectTitle;

  /// No description provided for @deleteProjectBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed. Its events, tasks and billables are kept.'**
  String deleteProjectBody(String name);

  /// No description provided for @newContact.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get newContact;

  /// No description provided for @editContact.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get editContact;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactName;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @organizationLabel.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organizationLabel;

  /// Form group heading for the event identity fields
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get formGroupEvent;

  /// Form group heading for date/time fields
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get formGroupWhen;

  /// Form group heading for secondary fields
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get formGroupDetails;

  /// Form group heading for workspace/contact/project pickers
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get formGroupLinks;

  /// Form group heading for billing amount fields
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get formGroupAmount;

  /// Quick action button on contact detail that dials the contact
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callAction;

  /// Quick action button on contact detail that starts a pre-filled billable
  ///
  /// In en, this message translates to:
  /// **'Log time'**
  String get logTimeAction;

  /// No description provided for @contactNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get contactNotesLabel;

  /// No description provided for @defaultRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Default hourly rate (€)'**
  String get defaultRateLabel;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get invalidAmount;

  /// No description provided for @rolesLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace roles'**
  String get rolesLabel;

  /// No description provided for @roleHint.
  ///
  /// In en, this message translates to:
  /// **'Role, e.g. client'**
  String get roleHint;

  /// No description provided for @emptyContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'No contacts'**
  String get emptyContactsTitle;

  /// No description provided for @emptyContactsBody.
  ///
  /// In en, this message translates to:
  /// **'Keep the people and organizations you work with close by.'**
  String get emptyContactsBody;

  /// No description provided for @contactsModuleDisabled.
  ///
  /// In en, this message translates to:
  /// **'The contacts module is disabled in this workspace.'**
  String get contactsModuleDisabled;

  /// No description provided for @deleteContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete contact?'**
  String get deleteContactTitle;

  /// No description provided for @deleteContactBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from your lists.'**
  String deleteContactBody(String name);

  /// No description provided for @contactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactLabel;

  /// No description provided for @noContact.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noContact;

  /// No description provided for @linkedContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get linkedContacts;

  /// No description provided for @linkedTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get linkedTasks;

  /// No description provided for @linkedEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get linkedEvents;

  /// No description provided for @linkedNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get linkedNotes;

  /// No description provided for @linkedBillables.
  ///
  /// In en, this message translates to:
  /// **'Billable items'**
  String get linkedBillables;

  /// No description provided for @addNoteAction.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNoteAction;

  /// No description provided for @nothingLinkedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get nothingLinkedYet;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEvent;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventTitle;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @allDayLabel.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDayLabel;

  /// No description provided for @startsLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get startsLabel;

  /// No description provided for @endsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get endsLabel;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End must be after start'**
  String get endBeforeStart;

  /// No description provided for @weekView.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekView;

  /// No description provided for @agendaView.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get agendaView;

  /// No description provided for @todayButton.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayButton;

  /// No description provided for @previousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get previousWeek;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get nextWeek;

  /// No description provided for @movedEventConflicts.
  ///
  /// In en, this message translates to:
  /// **'Now overlaps {count} other event(s)'**
  String movedEventConflicts(int count);

  /// No description provided for @conflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule conflict'**
  String get conflictTitle;

  /// No description provided for @conflictBody.
  ///
  /// In en, this message translates to:
  /// **'This event overlaps with:'**
  String get conflictBody;

  /// No description provided for @moreConflicts.
  ///
  /// In en, this message translates to:
  /// **'+{count} more conflicts'**
  String moreConflicts(int count);

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnyway;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @emptyAgenda.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled this week.'**
  String get emptyAgenda;

  /// No description provided for @taskDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Task due'**
  String get taskDueLabel;

  /// No description provided for @calendarModuleDisabled.
  ///
  /// In en, this message translates to:
  /// **'The calendar module is disabled in this workspace.'**
  String get calendarModuleDisabled;

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed from your calendar.'**
  String deleteEventBody(String title);

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @noteTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get noteTitle;

  /// No description provided for @noteBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Write in Markdown…'**
  String get noteBodyHint;

  /// No description provided for @previewTab.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewTab;

  /// No description provided for @editTab.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editTab;

  /// No description provided for @noWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get noWorkspace;

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get searchNotes;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchHint;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching notes.'**
  String get noSearchResults;

  /// No description provided for @emptyNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get emptyNotesTitle;

  /// No description provided for @emptyNotesBody.
  ///
  /// In en, this message translates to:
  /// **'Capture useful details, ideas, and meeting notes.'**
  String get emptyNotesBody;

  /// No description provided for @notesModuleDisabled.
  ///
  /// In en, this message translates to:
  /// **'The notes module is disabled in this workspace.'**
  String get notesModuleDisabled;

  /// No description provided for @deleteNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get deleteNoteTitle;

  /// No description provided for @deleteNoteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed from your lists.'**
  String deleteNoteBody(String title);

  /// No description provided for @emptyWorkspacesTitle.
  ///
  /// In en, this message translates to:
  /// **'No workspaces yet'**
  String get emptyWorkspacesTitle;

  /// No description provided for @emptyWorkspacesBody.
  ///
  /// In en, this message translates to:
  /// **'Create a workspace to organize your work, e.g. DEV, Teaching or Maintenance.'**
  String get emptyWorkspacesBody;

  /// No description provided for @deleteWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace?'**
  String get deleteWorkspaceTitle;

  /// No description provided for @deleteWorkspaceBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be hidden everywhere. Its data is kept and nothing is permanently erased.'**
  String deleteWorkspaceBody(String name);

  /// No description provided for @dataSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data safety'**
  String get dataSafetyTitle;

  /// No description provided for @exportBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get exportBackupTitle;

  /// No description provided for @exportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a password-protected copy of your Tomera data and settings.'**
  String get exportBackupSubtitle;

  /// No description provided for @restoreBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreBackupTitle;

  /// No description provided for @restoreBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace this device\'s Tomera data with an encrypted backup.'**
  String get restoreBackupSubtitle;

  /// No description provided for @backupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPasswordTitle;

  /// No description provided for @backupPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get backupPasswordLabel;

  /// No description provided for @backupPasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get backupPasswordConfirmLabel;

  /// No description provided for @backupPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get backupPasswordTooShort;

  /// No description provided for @backupPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get backupPasswordsDoNotMatch;

  /// No description provided for @restoreBackupConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace Tomera data?'**
  String get restoreBackupConfirmTitle;

  /// No description provided for @restoreBackupConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Tomera will first create a rollback snapshot, then replace the data and settings on this device.'**
  String get restoreBackupConfirmBody;

  /// No description provided for @restoreBackupConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackupConfirmAction;

  /// No description provided for @backupWorking.
  ///
  /// In en, this message translates to:
  /// **'Preparing backup…'**
  String get backupWorking;

  /// No description provided for @restoreWorking.
  ///
  /// In en, this message translates to:
  /// **'Restoring backup…'**
  String get restoreWorking;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup ready.'**
  String get backupExported;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored.'**
  String get backupRestored;

  /// No description provided for @backupUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Portable backups are currently available on Android only.'**
  String get backupUnsupported;

  /// No description provided for @backupAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect or the backup was damaged.'**
  String get backupAuthenticationFailed;

  /// No description provided for @backupInvalidArchive.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid Tomera backup.'**
  String get backupInvalidArchive;

  /// No description provided for @backupUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup format is not supported by this version of Tomera.'**
  String get backupUnsupportedVersion;

  /// No description provided for @backupNewerSchema.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of Tomera.'**
  String get backupNewerSchema;

  /// No description provided for @backupCorrupted.
  ///
  /// In en, this message translates to:
  /// **'The backup failed its integrity checks and was not restored.'**
  String get backupCorrupted;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup operation could not be completed. Your existing data was kept.'**
  String get backupFailed;

  /// No description provided for @backupExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportAction;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
