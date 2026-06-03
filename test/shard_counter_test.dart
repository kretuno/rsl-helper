import 'package:flutter_test/flutter_test.dart';
import 'package:raid_shard_counter/src/data/default_counters.dart';
import 'package:raid_shard_counter/src/models/history_entry.dart';

void main() {
  test('default counters match planned mercy thresholds', () {
    final counters = defaultCounters();

    expect(counters, hasLength(6));
    expect(
      counters.firstWhere((counter) => counter.id == 'ancient').threshold,
      219,
    );
    expect(
      counters.firstWhere((counter) => counter.id == 'void').threshold,
      219,
    );
    expect(
      counters.firstWhere((counter) => counter.id == 'sacred').threshold,
      22,
    );
    expect(
      counters
          .firstWhere((counter) => counter.id == 'primal_mythical')
          .threshold,
      51,
    );
    expect(
      counters
          .firstWhere((counter) => counter.id == 'primal_legendary')
          .threshold,
      209,
    );
    expect(
      counters.firstWhere((counter) => counter.id == 'zircon').threshold,
      121,
    );
  });

  test('counter progress is clamped to the threshold', () {
    final counter = defaultCounters().first.copyWith(current: 999);

    expect(counter.progress, 1);
  });

  test('history entry round-trips through json', () {
    final entry = HistoryEntry(
      id: '1',
      counterId: 'ancient',
      action: 'plus10',
      delta: 10,
      before: 43,
      after: 53,
      createdAt: DateTime.utc(2026, 5, 1, 9, 30),
    );

    final restored = HistoryEntry.fromJson(entry.toJson());

    expect(restored.counterId, 'ancient');
    expect(restored.action, 'plus10');
    expect(restored.before, 43);
    expect(restored.after, 53);
  });
}
