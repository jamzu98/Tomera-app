// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tomera';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabToday => 'Today';

  @override
  String get tabWork => 'Work';

  @override
  String get tabTasks => 'Tasks';

  @override
  String get tabNotes => 'Notes';

  @override
  String get tabWorkspaces => 'Workspaces';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get tabFinance => 'Finance';

  @override
  String get allWorkspaces => 'All workspaces';

  @override
  String get allWorkspacesShort => 'All';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get unableToLoadTitle => 'Couldn’t load this yet';

  @override
  String get unableToLoadBody => 'Try again in a moment.';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get quickAddChooseWorkspace => 'Choose a workspace to continue.';

  @override
  String get moduleUnavailableInWorkspace => 'Not available in this workspace';

  @override
  String get moduleDisabledTitle => 'This module is turned off';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get setupTitle => 'Set up your first workspace';

  @override
  String get setupBody =>
      'A workspace keeps related tasks, events, notes, contacts, and billable work together.';

  @override
  String get createWorkspaceAction => 'Create workspace';

  @override
  String get tryDemoAction => 'Try an example workspace';

  @override
  String get demoDataNote =>
      'Example data is optional and can be removed from Today.';

  @override
  String get checklistTitle => 'Finish setting up Tomera';

  @override
  String get checklistProject => 'Create your first project';

  @override
  String get checklistTask => 'Plan your first task';

  @override
  String get checklistContact => 'Add a contact';

  @override
  String checklistProgress(int completed, int total) {
    return '$completed of $total complete';
  }

  @override
  String get dismissAction => 'Dismiss';

  @override
  String get removeDemoAction => 'Remove example data';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesBody => 'Your unsaved changes will be lost.';

  @override
  String get keepEditingAction => 'Keep editing';

  @override
  String get discardChangesAction => 'Discard changes';

  @override
  String get moreOptions => 'More options';

  @override
  String get parentRecordLabel => 'Parent record';

  @override
  String get noParentRecord => 'No parent';

  @override
  String get referencesLabel => 'References';

  @override
  String get addReferenceAction => 'Add reference';

  @override
  String get createTaskFromSelectionAction => 'Create task from selection';

  @override
  String get selectNoteTextFirst => 'Select some note text first.';

  @override
  String get workspaceRateLabel => 'Workspace rate (€)';

  @override
  String get activityTimeline => 'Activity';

  @override
  String get activityEvent => 'Event';

  @override
  String get activityCompletedTask => 'Completed task';

  @override
  String get activityNote => 'Note';

  @override
  String get activityTimer => 'Timer session';

  @override
  String get activityBillable => 'Billable';

  @override
  String get undo => 'Undo';

  @override
  String get taskStatusChanged => 'Task status updated.';

  @override
  String get billableStatusChanged => 'Billable status updated.';

  @override
  String get eventMoved => 'Event time updated.';

  @override
  String get taskDeleted => 'Task deleted.';

  @override
  String get noteDeleted => 'Note deleted.';

  @override
  String get eventDeleted => 'Event deleted.';

  @override
  String get billableDeleted => 'Billable item deleted.';

  @override
  String get tomorrowButton => 'Tomorrow';

  @override
  String get nextMondayButton => 'Next Monday';

  @override
  String get filtersLabel => 'Filters';

  @override
  String get todayActiveTimer => 'Active timer';

  @override
  String get todaySchedule => 'Schedule';

  @override
  String get todayTasks => 'Due tasks';

  @override
  String get todayUnbilled => 'Unbilled';

  @override
  String get todayUnbilledTime => 'Unbilled time';

  @override
  String get todayRecentNotes => 'Recent notes';

  @override
  String get todayNoActiveTimer => 'No timer is running.';

  @override
  String get todayNoEvent => 'Nothing else is scheduled today.';

  @override
  String get todayNoTasks => 'No overdue tasks or tasks due today.';

  @override
  String get todayNoUnbilled => 'No unbilled work in this view.';

  @override
  String get todayNoNotes => 'No recent notes in this view.';

  @override
  String get todayOngoing => 'Ongoing';

  @override
  String get todayNext => 'Next';

  @override
  String todayHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String todayMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get newWorkspace => 'New workspace';

  @override
  String get editWorkspace => 'Edit workspace';

  @override
  String get workspaceName => 'Name';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get colorLabel => 'Color';

  @override
  String get iconLabel => 'Icon';

  @override
  String get modulesLabel => 'Modules';

  @override
  String get moduleCalendar => 'Calendar';

  @override
  String get moduleTasks => 'Tasks';

  @override
  String get moduleNotes => 'Notes';

  @override
  String get moduleContacts => 'Contacts';

  @override
  String get moduleFinance => 'Finance';

  @override
  String get newTask => 'New task';

  @override
  String get editTask => 'Edit task';

  @override
  String get taskTitle => 'Title';

  @override
  String get titleRequired => 'Enter a title';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get workspaceLabel => 'Workspace';

  @override
  String get priorityLabel => 'Priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'High';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusDone => 'Done';

  @override
  String get dueDateLabel => 'Due date';

  @override
  String get dueTimeLabel => 'Time';

  @override
  String get clearDueDate => 'Clear due date';

  @override
  String get reminderLabel => 'Reminder';

  @override
  String get reminderDateLabel => 'Reminder date';

  @override
  String get clearReminder => 'Clear reminder';

  @override
  String get remindNone => 'No reminder';

  @override
  String get remindAtStart => 'At start';

  @override
  String get remind15m => '15 minutes before';

  @override
  String get remind1h => '1 hour before';

  @override
  String get remind1d => '1 day before';

  @override
  String get groupByStatus => 'Status';

  @override
  String get groupByDueDate => 'Due date';

  @override
  String get filterOverdue => 'Overdue';

  @override
  String get dueSectionOverdue => 'Overdue';

  @override
  String get dueSectionToday => 'Today';

  @override
  String get dueSectionThisWeek => 'This week';

  @override
  String get dueSectionLater => 'Later';

  @override
  String get dueSectionNoDueDate => 'No due date';

  @override
  String get emptyTasksTitle => 'No tasks';

  @override
  String get emptyTasksBody => 'Capture the next thing you need to do.';

  @override
  String get tasksModuleDisabled =>
      'The tasks module is disabled in this workspace.';

  @override
  String get deleteTaskTitle => 'Delete task?';

  @override
  String deleteTaskBody(String title) {
    return '\"$title\" will be removed from your lists.';
  }

  @override
  String get createWorkspaceFirst => 'Create a workspace first.';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get nothingToExport => 'Nothing to export.';

  @override
  String get itemsTab => 'Items';

  @override
  String get summaryTab => 'Summary';

  @override
  String get overviewLabel => 'Overview';

  @override
  String get byWorkspaceLabel => 'By workspace';

  @override
  String get byContactLabel => 'By contact';

  @override
  String get hoursThisMonth => 'Hours this month';

  @override
  String get invoicedUnpaid => 'Invoiced, unpaid';

  @override
  String get paidThisMonth => 'Paid this month';

  @override
  String get thisMonthButton => 'This month';

  @override
  String get workTimer => 'Work timer';

  @override
  String get startTimer => 'Start timer';

  @override
  String get stopTimer => 'Stop';

  @override
  String get timerRunning => 'Timer running';

  @override
  String get timerSessionTitle => 'Timer session';

  @override
  String get timerSessionNotFound =>
      'This timer session is no longer available.';

  @override
  String get timerAlreadyRunning => 'A timer is already running.';

  @override
  String get unconvertedTime => 'Unconverted time';

  @override
  String get unconvertedTimeBody =>
      'Stopped timers stay here until they become billable items.';

  @override
  String get convertToBillable => 'Convert to billable';

  @override
  String get timerConverted => 'Timer converted to a billable item.';

  @override
  String get timerConversionFailed => 'Couldn’t convert this timer. Try again.';

  @override
  String get repeatLabel => 'Repeat';

  @override
  String get doesNotRepeat => 'Does not repeat';

  @override
  String get recurrenceFrequencyLabel => 'Frequency';

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get recurrenceYearly => 'Yearly';

  @override
  String get repeatEveryLabel => 'Repeat every';

  @override
  String get intervalUnitDays => 'day(s)';

  @override
  String get intervalUnitWeeks => 'week(s)';

  @override
  String get intervalUnitMonths => 'month(s)';

  @override
  String get intervalUnitYears => 'year(s)';

  @override
  String get repeatOnLabel => 'Repeat on';

  @override
  String get recurrenceEndsLabel => 'Ends';

  @override
  String get recurrenceNeverEnds => 'Never';

  @override
  String get recurrenceOnDate => 'On date';

  @override
  String get recurrenceAfterCount => 'After count';

  @override
  String get inclusiveEndDateLabel => 'Inclusive end date';

  @override
  String get occurrenceCountLabel => 'Occurrences';

  @override
  String get repeatAnchorLabel => 'Next task advances';

  @override
  String get repeatFromSchedule => 'From prior due date';

  @override
  String get repeatFromCompletion => 'From completion time';

  @override
  String get recurrenceRequiresDueDate =>
      'Choose a due date before enabling repeat.';

  @override
  String get recurrenceReminderBeforeDue =>
      'A repeating task reminder must be at or before its due time.';

  @override
  String get recurringSeriesContext => 'Part of a recurring series';

  @override
  String get editRecurringTitle => 'Edit recurring event';

  @override
  String get editThisOccurrence => 'This occurrence';

  @override
  String get editCurrentAndFuture => 'This and future occurrences';

  @override
  String get deleteRecurringTitle => 'Delete recurring event';

  @override
  String get deleteThisOccurrence => 'Delete this occurrence';

  @override
  String get deleteCurrentAndFuture => 'Delete this and future occurrences';

  @override
  String get invalidInterval => 'Enter a whole number greater than zero';

  @override
  String get invalidOccurrenceCount => 'Enter at least one occurrence';

  @override
  String get recurrenceEndBeforeStart =>
      'The repeat end must include at least one occurrence.';

  @override
  String recurrenceTimezone(String timezone) {
    return 'Time zone: $timezone';
  }

  @override
  String get cannotReopenRecurringTask =>
      'This task can’t be reopened because its next occurrence has already progressed.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get roundingLabel => 'Timer duration rounding';

  @override
  String get weekStartLabel => 'Week starts on';

  @override
  String get weekStartMonday => 'Monday';

  @override
  String get weekStartSunday => 'Sunday';

  @override
  String get timeFormatLabel => 'Time format';

  @override
  String get timeFormatSystem => 'System default';

  @override
  String get timeFormat12 => '12-hour';

  @override
  String get timeFormat24 => '24-hour';

  @override
  String get roundingNone => 'No rounding';

  @override
  String roundingOption(int minutes) {
    return '$minutes minutes, round up';
  }

  @override
  String get newBillable => 'New billable item';

  @override
  String get editBillable => 'Edit billable item';

  @override
  String get typeLabel => 'Type';

  @override
  String get typeHourly => 'Hourly';

  @override
  String get typeFixed => 'Fixed';

  @override
  String get rateLabel => 'Rate (€/h)';

  @override
  String get durationMinutesLabel => 'Duration (min)';

  @override
  String get amountLabel => 'Amount (€)';

  @override
  String get currencyLabel => 'Currency';

  @override
  String get billableStatusLabel => 'Status';

  @override
  String get statusUnbilled => 'Unbilled';

  @override
  String get statusInvoiced => 'Invoiced';

  @override
  String get statusPaid => 'Paid';

  @override
  String get emptyBillablesTitle => 'No billable items';

  @override
  String get emptyBillablesBody =>
      'Track time or a fixed amount you can bill later.';

  @override
  String get financeModuleDisabled =>
      'The finance module is disabled in this workspace.';

  @override
  String get deleteBillableTitle => 'Delete billable item?';

  @override
  String deleteBillableBody(String title) {
    return '\"$title\" will be removed from your lists.';
  }

  @override
  String get financialSummary => 'Financial summary';

  @override
  String get invalidDuration => 'Enter minutes as a whole number';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get addInstances => 'Add instances';

  @override
  String get defaultTimeLabel => 'Default time';

  @override
  String get applyToAll => 'Apply to all';

  @override
  String get repeatWeeklyOnLabel => 'Repeat weekly on';

  @override
  String get fromLabel => 'From';

  @override
  String get untilLabel => 'Until';

  @override
  String get generateDates => 'Generate dates';

  @override
  String get pickDatesLabel => 'Or pick dates manually';

  @override
  String get addSelectedDates => 'Add selected dates';

  @override
  String instancesCount(int count) {
    return 'Instances ($count)';
  }

  @override
  String get addSingleDate => 'Add date';

  @override
  String get noInstancesYet =>
      'No dates yet — generate from a pattern or pick dates above.';

  @override
  String createInstances(int count) {
    return 'Create $count events';
  }

  @override
  String instanceConflicts(int count) {
    return '$count of the new events overlap existing ones:';
  }

  @override
  String get newProject => 'New project';

  @override
  String get editProject => 'Edit project';

  @override
  String get projectLabel => 'Project';

  @override
  String get noProject => 'None';

  @override
  String get archivedLabel => 'Archived';

  @override
  String get showArchived => 'Show archived';

  @override
  String get useWorkspaceColor => 'Workspace color';

  @override
  String get emptyProjectsTitle => 'No projects';

  @override
  String get emptyProjectsBody =>
      'Group a course, a client gig or any recurring work with the + button.';

  @override
  String get deleteProjectTitle => 'Delete project?';

  @override
  String deleteProjectBody(String name) {
    return '\"$name\" will be removed. Its events, tasks and billables are kept.';
  }

  @override
  String get newContact => 'New contact';

  @override
  String get editContact => 'Edit contact';

  @override
  String get contactName => 'Name';

  @override
  String get emailLabel => 'Email';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get organizationLabel => 'Organization';

  @override
  String get formGroupEvent => 'Event';

  @override
  String get formGroupWhen => 'When';

  @override
  String get formGroupDetails => 'Details';

  @override
  String get formGroupLinks => 'Links';

  @override
  String get formGroupAmount => 'Amount';

  @override
  String get callAction => 'Call';

  @override
  String get logTimeAction => 'Log time';

  @override
  String get contactNotesLabel => 'Notes';

  @override
  String get defaultRateLabel => 'Default hourly rate (€)';

  @override
  String get invalidAmount => 'Enter a valid amount';

  @override
  String get rolesLabel => 'Workspace roles';

  @override
  String get roleHint => 'Role, e.g. client';

  @override
  String get emptyContactsTitle => 'No contacts';

  @override
  String get emptyContactsBody =>
      'Keep the people and organizations you work with close by.';

  @override
  String get contactsModuleDisabled =>
      'The contacts module is disabled in this workspace.';

  @override
  String get deleteContactTitle => 'Delete contact?';

  @override
  String deleteContactBody(String name) {
    return '\"$name\" will be removed from your lists.';
  }

  @override
  String get contactLabel => 'Contact';

  @override
  String get noContact => 'None';

  @override
  String get linkedContacts => 'Contacts';

  @override
  String get linkedTasks => 'Tasks';

  @override
  String get linkedEvents => 'Events';

  @override
  String get linkedNotes => 'Notes';

  @override
  String get linkedBillables => 'Billable items';

  @override
  String get addNoteAction => 'Add note';

  @override
  String get nothingLinkedYet => 'Nothing here yet.';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get eventTitle => 'Title';

  @override
  String get locationLabel => 'Location';

  @override
  String get allDayLabel => 'All day';

  @override
  String get startsLabel => 'Starts';

  @override
  String get endsLabel => 'Ends';

  @override
  String get endBeforeStart => 'End must be after start';

  @override
  String get weekView => 'Week';

  @override
  String get agendaView => 'Agenda';

  @override
  String get todayButton => 'Today';

  @override
  String get previousWeek => 'Previous week';

  @override
  String get nextWeek => 'Next week';

  @override
  String movedEventConflicts(int count) {
    return 'Now overlaps $count other event(s)';
  }

  @override
  String get conflictTitle => 'Schedule conflict';

  @override
  String get conflictBody => 'This event overlaps with:';

  @override
  String moreConflicts(int count) {
    return '+$count more conflicts';
  }

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get goBack => 'Go back';

  @override
  String get emptyAgenda => 'Nothing scheduled this week.';

  @override
  String get taskDueLabel => 'Task due';

  @override
  String get calendarModuleDisabled =>
      'The calendar module is disabled in this workspace.';

  @override
  String get deleteEventTitle => 'Delete event?';

  @override
  String deleteEventBody(String title) {
    return '\"$title\" will be removed from your calendar.';
  }

  @override
  String get newNote => 'New note';

  @override
  String get editNote => 'Edit note';

  @override
  String get noteTitle => 'Title';

  @override
  String get noteBodyHint => 'Write in Markdown…';

  @override
  String get previewTab => 'Preview';

  @override
  String get editTab => 'Edit';

  @override
  String get noWorkspace => 'No workspace';

  @override
  String get searchNotes => 'Search notes';

  @override
  String get searchHint => 'Search…';

  @override
  String get closeSearch => 'Close search';

  @override
  String get noSearchResults => 'No matching notes.';

  @override
  String get emptyNotesTitle => 'No notes';

  @override
  String get emptyNotesBody =>
      'Capture useful details, ideas, and meeting notes.';

  @override
  String get notesModuleDisabled =>
      'The notes module is disabled in this workspace.';

  @override
  String get deleteNoteTitle => 'Delete note?';

  @override
  String deleteNoteBody(String title) {
    return '\"$title\" will be removed from your lists.';
  }

  @override
  String get emptyWorkspacesTitle => 'No workspaces yet';

  @override
  String get emptyWorkspacesBody =>
      'Create a workspace to organize your work, e.g. DEV, Teaching or Maintenance.';

  @override
  String get deleteWorkspaceTitle => 'Delete workspace?';

  @override
  String deleteWorkspaceBody(String name) {
    return '\"$name\" will be hidden everywhere. Its data is kept and nothing is permanently erased.';
  }

  @override
  String get dataSafetyTitle => 'Data safety';

  @override
  String get exportBackupTitle => 'Export encrypted backup';

  @override
  String get exportBackupSubtitle =>
      'Save a password-protected copy of your Tomera data and settings.';

  @override
  String get restoreBackupTitle => 'Restore from backup';

  @override
  String get restoreBackupSubtitle =>
      'Replace this device\'s Tomera data with an encrypted backup.';

  @override
  String get backupPasswordTitle => 'Backup password';

  @override
  String get backupPasswordLabel => 'Password';

  @override
  String get backupPasswordConfirmLabel => 'Confirm password';

  @override
  String get backupPasswordTooShort => 'Use at least 8 characters.';

  @override
  String get backupPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get restoreBackupConfirmTitle => 'Replace Tomera data?';

  @override
  String get restoreBackupConfirmBody =>
      'Tomera will first create a rollback snapshot, then replace the data and settings on this device.';

  @override
  String get restoreBackupConfirmAction => 'Restore backup';

  @override
  String get backupWorking => 'Preparing backup…';

  @override
  String get restoreWorking => 'Restoring backup…';

  @override
  String get backupExported => 'Encrypted backup ready.';

  @override
  String get backupRestored => 'Backup restored.';

  @override
  String get backupUnsupported =>
      'Portable backups are currently available on Android only.';

  @override
  String get backupAuthenticationFailed =>
      'The password is incorrect or the backup was damaged.';

  @override
  String get backupInvalidArchive => 'This is not a valid Tomera backup.';

  @override
  String get backupUnsupportedVersion =>
      'This backup format is not supported by this version of Tomera.';

  @override
  String get backupNewerSchema =>
      'This backup was created by a newer version of Tomera.';

  @override
  String get backupCorrupted =>
      'The backup failed its integrity checks and was not restored.';

  @override
  String get backupFailed =>
      'The backup operation could not be completed. Your existing data was kept.';

  @override
  String get backupExportAction => 'Export';

  @override
  String get continueAction => 'Continue';

  @override
  String get cancelAction => 'Cancel';
}
