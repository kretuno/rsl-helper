class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.counterId,
    required this.action,
    required this.delta,
    required this.before,
    required this.after,
    required this.createdAt,
  });

  final String id;
  final String counterId;
  final String action;
  final int delta;
  final int before;
  final int after;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'counterId': counterId,
    'action': action,
    'delta': delta,
    'before': before,
    'after': after,
    'createdAt': createdAt.toIso8601String(),
  };

  static HistoryEntry fromJson(Map<String, Object?> json) {
    return HistoryEntry(
      id: json['id'] as String? ?? '',
      counterId: json['counterId'] as String? ?? '',
      action: json['action'] as String? ?? '',
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      before: (json['before'] as num?)?.toInt() ?? 0,
      after: (json['after'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
