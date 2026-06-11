import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_state_snapshot.dart';
import '../models/history_entry.dart';
import '../models/shard_counter.dart';

class ShardStore {
  bool get isFirebaseSupported => kIsWeb ? true : (!Platform.isWindows && !Platform.isLinux);

  Future<AppStateSnapshot?> load() async {
    // 1. Load local data first
    String? localRaw = await _loadLocalRaw();
    AppStateSnapshot? localSnapshot;
    DateTime? localSavedAt;
    
    if (localRaw != null) {
      try {
        localSnapshot = decode(localRaw);
        final decodedMap = jsonDecode(localRaw) as Map<String, Object?>;
        if (decodedMap['savedAt'] is String) {
          localSavedAt = DateTime.tryParse(decodedMap['savedAt'] as String);
        }
      } catch (e) {
        debugPrint('Error decoding local data: $e');
      }
    }

    // 2. If Firebase is supported and user is logged in, sync with cloud
    if (isFirebaseSupported) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data();
            if (data != null) {
              final cloudSavedAtStr = data['savedAt'] as String?;
              final cloudSavedAt = cloudSavedAtStr != null ? DateTime.tryParse(cloudSavedAtStr) : null;
              
              final cloudCounters = data['counters'] as List<dynamic>? ?? [];
              final cloudHistory = data['history'] as List<dynamic>? ?? [];

              // Map cloud fields to Snapshot
              final currents = <String, int>{};
              for (final entry in cloudCounters) {
                if (entry is Map) {
                  final id = entry['id'] as String?;
                  final current = (entry['current'] as num?)?.toInt();
                  if (id != null && current != null) {
                    currents[id] = current;
                  }
                }
              }

              final history = <HistoryEntry>[];
              for (final entry in cloudHistory) {
                if (entry is Map) {
                  history.add(HistoryEntry.fromJson(Map<String, Object?>.from(entry)));
                }
              }

              final cloudSnapshot = AppStateSnapshot(currents: currents, history: history);

              // 3. Compare timestamps
              if (localSavedAt == null || (cloudSavedAt != null && cloudSavedAt.isAfter(localSavedAt))) {
                // Cloud is newer: update local and return cloud
                debugPrint('Cloud data is newer (${cloudSavedAtStr}). Overwriting local cache.');
                final encodedCloud = encode(
                  cloudSnapshot.currents.entries.map((e) => ShardCounter(
                    id: e.key, current: e.value, title: '', description: '', assetPath: '', accentColor: const Color(0), threshold: 0, chanceLabel: '', rewardType: '',
                  )).toList(),
                  cloudSnapshot.history,
                  savedAt: cloudSavedAt,
                );
                await _saveLocalRaw(encodedCloud);
                return cloudSnapshot;
              } else {
                // Local is newer: upload local to cloud
                debugPrint('Local data is newer (${localSavedAt.toIso8601String()}). Uploading to cloud.');
                if (localSnapshot != null) {
                  await _saveToCloud(user.uid, localSnapshot, localSavedAt);
                }
                return localSnapshot;
              }
            }
          } else {
            // Document does not exist in Cloud: push local data to Cloud
            if (localSnapshot != null) {
              debugPrint('Document not found in cloud. Uploading local data.');
              await _saveToCloud(user.uid, localSnapshot, localSavedAt ?? DateTime.now());
            }
          }
        } catch (e) {
          debugPrint('Error syncing with Firebase on load: $e');
        }
      }
    }

    return localSnapshot;
  }

  Future<void> save(
    List<ShardCounter> counters,
    List<HistoryEntry> history,
  ) async {
    final now = DateTime.now();
    final raw = encode(counters, history, savedAt: now);
    
    // Save locally
    await _saveLocalRaw(raw);

    // Save to Cloud in background if supported and logged in
    if (isFirebaseSupported) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final snapshot = AppStateSnapshot(
            currents: {for (var c in counters) c.id: c.current},
            history: history,
          );
          await _saveToCloud(user.uid, snapshot, now);
        } catch (e) {
          debugPrint('Error saving to Cloud: $e');
        }
      }
    }
  }

  Future<void> syncLocalToCloud() async {
    if (!isFirebaseSupported) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final localRaw = await _loadLocalRaw();
      if (localRaw != null) {
        final decodedMap = jsonDecode(localRaw) as Map<String, Object?>;
        DateTime? localSavedAt;
        if (decodedMap['savedAt'] is String) {
          localSavedAt = DateTime.tryParse(decodedMap['savedAt'] as String);
        }
        final localSnapshot = decode(localRaw);
        
        // Fetch cloud data to compare timestamps
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final cloudSavedAtStr = data['savedAt'] as String?;
            final cloudSavedAt = cloudSavedAtStr != null ? DateTime.tryParse(cloudSavedAtStr) : null;
            
            if (localSavedAt != null && cloudSavedAt != null && cloudSavedAt.isAfter(localSavedAt)) {
              // Cloud is newer, don't overwrite it, but we can load/cache it locally
              debugPrint('syncLocalToCloud: Cloud is newer, skipping upload.');
              return;
            }
          }
        }
        
        debugPrint('syncLocalToCloud: Uploading local data to Cloud.');
        await _saveToCloud(user.uid, localSnapshot, localSavedAt ?? DateTime.now());
      }
    } catch (e) {
      debugPrint('Error syncing local to cloud: $e');
    }
  }

  Future<void> _saveToCloud(String userId, AppStateSnapshot snapshot, DateTime savedAt) async {
    final countersList = snapshot.currents.entries.map((e) => {
      'id': e.key,
      'current': e.value,
    }).toList();
    
    final historyList = snapshot.history.map((h) => h.toJson()).toList();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'email': email,
      'savedAt': savedAt.toIso8601String(),
      'counters': countersList,
      'history': historyList,
    }, SetOptions(merge: true));
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
    List<HistoryEntry> history, {
    DateTime? savedAt,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'savedAt': (savedAt ?? DateTime.now()).toIso8601String(),
      'counters': counters.map((counter) => counter.toJson()).toList(),
      'history': history.map((entry) => entry.toJson()).toList(),
    });
  }

  // Local helper to load raw JSON
  Future<String?> _loadLocalRaw() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('shard_state');
    } else {
      final file = await _stateFile();
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    }
  }

  // Local helper to save raw JSON
  Future<void> _saveLocalRaw(String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shard_state', value);
    } else {
      final file = await _stateFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(value);
    }
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
