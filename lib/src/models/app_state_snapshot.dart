import 'history_entry.dart';

class AppStateSnapshot {
  const AppStateSnapshot({required this.currents, required this.history});

  final Map<String, int> currents;
  final List<HistoryEntry> history;
}
