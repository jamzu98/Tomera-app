import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';

String moduleLabel(AppLocalizations l10n, ModuleKey module) => switch (module) {
      ModuleKey.calendar => l10n.moduleCalendar,
      ModuleKey.tasks => l10n.moduleTasks,
      ModuleKey.notes => l10n.moduleNotes,
      ModuleKey.contacts => l10n.moduleContacts,
      ModuleKey.finance => l10n.moduleFinance,
    };
