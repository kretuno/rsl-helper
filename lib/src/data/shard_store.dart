import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/app_state_snapshot.dart';
import '../models/history_entry.dart';
import '../models/shard_counter.dart';

class ShardStore {
  Future<AppStateSnapshot?> load() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    return decode(raw);
  }

  static AppStateSnapshot decode(String raw) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    final counters = <String, int>{};
    final rawCounters = json['counters'];
    if (rawCounters is List) {
      for (final entry in rawCounters) {
        if (entry is Map) {
          final id = entry['id'] as String?;
          final current = (entry['current'] as num?)?.toInt();
          if (id != null && current != null) {
            counters[id] = current;
          }
        }
      }
    }

    final history = <HistoryEntry>[];
    final rawHistory = json['history'];
    if (rawHistory is List) {
      for (final entry in rawHistory) {
        if (entry is Map) {
          history.add(HistoryEntry.fromJson(Map<String, Object?>.from(entry)));
        }
      }
    }

    return AppStateSnapshot(currents: counters, history: history);
  }

  static String encode(
    List<ShardCounter> counters,
    List<HistoryEntry> history,
  ) {
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'counters': counters.map((counter) => counter.toJson()).toList(),
      'history': history.map((entry) => entry.toJson()).toList(),
    });
  }

  Future<void> save(
    List<ShardCounter> counters,
    List<HistoryEntry> history,
  ) async {
    final file = await _stateFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(encode(counters, history));
  }

  Future<File> _stateFile() async {
    return File('${await _basePath()}${Platform.pathSeparator}state.json');
  }

  Future<String> _basePath() async {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return '${env['APPDATA'] ?? Directory.current.path}${Platform.pathSeparator}RaidShardCounter';
    }
    if (Platform.isMacOS) {
      return '${env['HOME'] ?? Directory.current.path}${Platform.pathSeparator}Library${Platform.pathSeparator}Application Support${Platform.pathSeparator}RaidShardCounter';
    }
    if (Platform.isAndroid) {
      const channel = MethodChannel('raid_shard_counter/app_paths');
      final path = await channel.invokeMethod<String>('dataDir');
      if (path != null && path.isNotEmpty) {
        return '$path${Platform.pathSeparator}RaidShardCounter';
      }
      return '${Directory.systemTemp.path}${Platform.pathSeparator}RaidShardCounter';
    }
    return '${env['XDG_DATA_HOME'] ?? '${env['HOME'] ?? Directory.current.path}${Platform.pathSeparator}.local${Platform.pathSeparator}share'}${Platform.pathSeparator}RaidShardCounter';
  }
}
