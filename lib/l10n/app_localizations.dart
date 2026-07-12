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
  /// **'Add a task with the + button.'**
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

  /// No description provided for @timerAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A timer is already running.'**
  String get timerAlreadyRunning;

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
  /// **'Add a billable item with the + button.'**
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

  /// No description provided for @repeatOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat weekly on'**
  String get repeatOnLabel;

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
  /// **'Add a contact with the + button.'**
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
  /// **'Add a note with the + button.'**
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
