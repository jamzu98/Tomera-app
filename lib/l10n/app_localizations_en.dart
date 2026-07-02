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
