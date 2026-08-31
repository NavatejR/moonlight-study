import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The list of screens reachable from the navigation shell.
enum AppSection {
  dashboard,
  notebooks,
  chat,
  flashcards,
  planner,
  music,
  models,
  settings,
}

/// Currently selected [AppSection] in the shell.
final appSectionProvider =
    NotifierProvider<AppSectionNotifier, AppSection>(AppSectionNotifier.new);

class AppSectionNotifier extends Notifier<AppSection> {
  @override
  AppSection build() => AppSection.dashboard;

  void select(AppSection section) => state = section;
}

/// The section the shell should actually render once AI availability is
/// accounted for. Chat needs a model, so when [aiEnabled] is false it is
/// replaced by [AppSection.dashboard] (identical to the shell's default)
/// without ever mutating provider state.
AppSection effectiveSectionFor(AppSection section, {required bool aiEnabled}) {
  if (!aiEnabled && section == AppSection.chat) return AppSection.dashboard;
  return section;
}