import 'package:letter_signing/l10n/app_localizations.dart';

/// Persian name of a server module code for headings and chips; unknown codes show as is.
String moduleLabel(AppLocalizations l, String module) => switch (module) {
  'tasks' => l.moduleTasks,
  'projects' => l.moduleProjects,
  'letters' => l.moduleLetters,
  'meetings' => l.moduleMeetings,
  'notes' => l.moduleNotes,
  'crm' => l.searchModuleCrm,
  'chat' => l.searchModuleChat,
  'finance' => l.searchModuleFinance,
  'sales' => l.searchModuleSales,
  'files' => l.searchModuleFiles,
  _ => module,
};
