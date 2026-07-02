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
