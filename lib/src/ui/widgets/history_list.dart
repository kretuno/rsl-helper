import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/history_entry.dart';
import '../../models/shard_counter.dart';
import '../../services/translation_service.dart';
import '../../theme/app_colors.dart';

class HistoryList extends StatelessWidget {
  const HistoryList({
    required this.history,
    required this.counters,
    this.controller,
    this.compact = false,
    super.key,
  });

  final List<HistoryEntry> history;
  final List<ShardCounter> counters;
  final ScrollController? controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final counter in counters) counter.id: counter};
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.5),
        border: compact
            ? null
            : Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            compact ? TranslationService.t('recent_activity') : TranslationService.t('history'),
            style: GoogleFonts.outfit(
              fontSize: compact ? 22 : 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            ExpandedOrBox(
              compact: Text(TranslationService.t('no_activity_yet'), style: const TextStyle(color: AppColors.muted)),
              expanded: Center(
                child: Text(TranslationService.t('no_activity_yet'), style: const TextStyle(color: AppColors.muted)),
              ),
            )
          else
            ExpandedOrBox(
              compact: Column(
                children: [
                  for (final entry in history)
                    _HistoryTile(entry: entry, counter: byId[entry.counterId]),
                ],
              ),
              expanded: Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: history.length,
                  itemBuilder: (context, index) => _HistoryTile(
                    entry: history[index],
                    counter: byId[history[index].counterId],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ExpandedOrBox extends StatelessWidget {
  const ExpandedOrBox({
    required this.compact,
    required this.expanded,
    super.key,
  });

  final Widget compact;
  final Widget expanded;

  @override
  Widget build(BuildContext context) {
    final inScrollable =
        context.findAncestorWidgetOfExactType<ListView>() != null;
    return inScrollable ? compact : expanded;
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.counter});

  final HistoryEntry entry;
  final ShardCounter? counter;

  @override
  Widget build(BuildContext context) {
    final title = counter?.title ?? entry.counterId;
    final delta = entry.delta > 0 ? '+${entry.delta}' : '${entry.delta}';
    final isReset = entry.action == 'reset';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (counter != null)
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: counter!.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(counter!.assetPath),
            ),
          if (counter != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_actionLabel(entry.action)}: ${entry.before} → ${entry.after} ($delta)',
                  style: GoogleFonts.inter(
                    color: isReset ? AppColors.red.withValues(alpha: 0.8) : Colors.white60,
                    fontSize: 12,
                    fontWeight: isReset ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(entry.createdAt),
            style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _actionLabel(String action) {
    return switch (action) {
      'plus' => '+1',
      'plus10' => '+10',
      'minus' => '-1',
      'manual' => TranslationService.t('manual_entry'),
      'reset' => TranslationService.t('pity_reset_msg'),
      _ => action,
    };
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
