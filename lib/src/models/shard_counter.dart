import 'package:flutter/material.dart';

class ShardCounter {
  const ShardCounter({
    required this.id,
    required this.title,
    required this.description,
    required this.assetPath,
    required this.accentColor,
    required this.current,
    required this.threshold,
    required this.chanceLabel,
    required this.rewardType,
  });

  final String id;
  final String title;
  final String description;
  final String assetPath;
  final Color accentColor;
  final int current;
  final int threshold;
  final String chanceLabel;
  final String rewardType;

  double get progress =>
      threshold == 0 ? 0 : (current / threshold).clamp(0.0, 1.0).toDouble();

  ShardCounter copyWith({int? current}) {
    return ShardCounter(
      id: id,
      title: title,
      description: description,
      assetPath: assetPath,
      accentColor: accentColor,
      current: current ?? this.current,
      threshold: threshold,
      chanceLabel: chanceLabel,
      rewardType: rewardType,
    );
  }

  Map<String, Object?> toJson() => {'id': id, 'current': current};
}
