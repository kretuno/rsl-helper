import 'package:flutter/material.dart';
import '../models/shard_counter.dart';
import '../services/translation_service.dart';
import '../theme/app_colors.dart';

List<ShardCounter> defaultCounters() {
  return [
    ShardCounter(
      id: 'ancient',
      title: TranslationService.t('ancient_title'),
      description: TranslationService.t('ancient_desc'),
      assetPath: 'assets/shards/1002.png',
      accentColor: AppColors.blue,
      current: 0,
      threshold: 219,
      chanceLabel: '${TranslationService.t('legendary_chance')}: 0,5%',
      rewardType: 'legendary',
    ),
    ShardCounter(
      id: 'void',
      title: TranslationService.t('void_title'),
      description: TranslationService.t('void_desc'),
      assetPath: 'assets/shards/1004.png',
      accentColor: AppColors.purple,
      current: 0,
      threshold: 219,
      chanceLabel: '${TranslationService.t('legendary_chance')}: 0,5%',
      rewardType: 'legendary',
    ),
    ShardCounter(
      id: 'zircon',
      title: TranslationService.t('zircon_title'),
      description: TranslationService.t('zircon_desc'),
      assetPath: 'assets/shards/zircon.png',
      accentColor: AppColors.red,
      current: 0,
      threshold: 219,
      chanceLabel: '${TranslationService.t('legendary_chance')}: 0,5%',
      rewardType: 'legendary',
    ),
    ShardCounter(
      id: 'sacred',
      title: TranslationService.t('sacred_title'),
      description: TranslationService.t('sacred_desc'),
      assetPath: 'assets/shards/1003.png',
      accentColor: AppColors.yellow,
      current: 0,
      threshold: 22,
      chanceLabel: '${TranslationService.t('legendary_chance')}: 6%',
      rewardType: 'legendary',
    ),
    ShardCounter(
      id: 'primal_mythical',
      title: TranslationService.t('primal_mythical_title'),
      description: TranslationService.t('primal_mythical_desc'),
      assetPath: 'assets/shards/1005.png',
      accentColor: AppColors.red,
      current: 0,
      threshold: 219,
      chanceLabel: '${TranslationService.t('mythical_chance')}: 0,5%',
      rewardType: 'mythical',
    ),
    ShardCounter(
      id: 'primal_legendary',
      title: TranslationService.t('primal_legendary_title'),
      description: TranslationService.t('primal_legendary_desc'),
      assetPath: 'assets/shards/primal_alt.png',
      accentColor: Colors.orange,
      current: 0,
      threshold: 51,
      chanceLabel: '${TranslationService.t('legendary_chance')}: 1%',
      rewardType: 'legendary',
    ),  ];
}
