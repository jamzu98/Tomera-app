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
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

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
  String get emptyTasksBody => 'Add a task with the + button.';

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
  String get timerAlreadyRunning => 'A timer is already running.';

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
  String get emptyBillablesBody => 'Add a billable item with the + button.';

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
  String get emptyContactsBody => 'Add a contact with the + button.';

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
  String get conflictTitle => 'Schedule conflict';

  @override
  String get conflictBody => 'This event overlaps with:';

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
  String get emptyNotesBody => 'Add a note with the + button.';

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
}
