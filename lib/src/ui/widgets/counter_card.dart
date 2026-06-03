import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shard_counter.dart';
import '../../services/translation_service.dart';
import '../../theme/app_colors.dart';
import 'progress_ring.dart';

class CounterCard extends StatefulWidget {
  const CounterCard({
    required this.counter,
    required this.onChange,
    this.onResetAnimation,
    super.key,
  });

  final ShardCounter counter;
  final void Function(ShardCounter counter, int value, String action) onChange;
  final VoidCallback? onResetAnimation;

  @override
  State<CounterCard> createState() => CounterCardState();
}

class CounterCardState extends State<CounterCard>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  bool _isHovered = false;
  late final AnimationController _hoverController;
  late final Animation<double> _scaleAnimation;

  // Анимация сброса (эффект победы)
  late final AnimationController _resetAnimationController;
  late final Animation<double> _resetScaleAnimation;
  bool _wasReset = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.counter.current}');
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    // Инициализация анимации сброса
    _resetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _resetScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _resetAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CounterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.counter.current != widget.counter.current) {
      _controller.text = '${widget.counter.current}';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  void triggerResetAnimation() {
    if (!mounted) return;
    setState(() {
      _wasReset = true;
    });
    _resetAnimationController.forward(from: 0.0);

    // Очистка состояния анимации через время
    Future.delayed(const Duration(milliseconds: 800), ( ) {
      if (mounted) {
        setState(() {
          _wasReset = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _hoverController.dispose();
    _resetAnimationController.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0 || value > widget.counter.threshold) {
      _controller.text = '${widget.counter.current}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value == null 
                ? TranslationService.t('invalid_number')
                : TranslationService.t('value_out_of_range')
                    .replaceAll('{max}', '${widget.counter.threshold}'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    widget.onChange(widget.counter, value, 'manual');
  }

  @override
  Widget build(BuildContext context) {
    final isMythical = widget.counter.rewardType == 'mythical';
    final accent = widget.counter.accentColor;
    final chanceColor = isMythical ? AppColors.red : AppColors.gold;
    final isHighPity = widget.counter.progress > 0.8;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: _isHovered ? 0.2 : 0.08),
                    blurRadius: _isHovered ? 40 : 25,
                    spreadRadius: _isHovered ? 8 : 0,
                  ),
                  if (isHighPity)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isHovered
                            ? accent.withValues(alpha: 0.8)
                            : (isHighPity 
                                ? accent.withValues(alpha: 0.5) 
                                : accent.withValues(alpha: 0.25)),
                        width: _isHovered || isHighPity ? 2.0 : 1.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.15),
                          AppColors.card.withValues(alpha: 0.1),
                          accent.withValues(alpha: 0.05),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 380;
                        return SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                height: 32,
                                alignment: Alignment.center,
                                child: Text(
                                  widget.counter.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: compact ? 18 : 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: compact ? 96 : 116,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.8, end: 1.0),
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      curve: Curves.elasticOut,
                                      builder: (context, val, child) =>
                                          Transform.scale(
                                        scale: val,
                                        child: SizedBox(
                                          width: compact ? 96 : 116,
                                          height: compact ? 96 : 116,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: AppColors.panel.withValues(alpha: 0.4),
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(
                                                  color: accent.withValues(alpha: 0.3),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: accent.withValues(alpha: 0.1),
                                                    blurRadius: 15,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Image.asset(
                                                widget.counter.assetPath,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: compact ? 96 : 116,
                                      height: compact ? 96 : 116,
                                      child: ProgressRing(
                                        counter: widget.counter,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 84,
                                child: Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _ActionButton(
                                        label: '-',
                                        color: accent,
                                        onTap: () => widget.onChange(
                                          widget.counter,
                                          widget.counter.current - 1,
                                          'minus',
                                        ),
                                      ),
                                      _ActionButton(
                                        label: '+',
                                        color: accent,
                                        onTap: () => widget.onChange(
                                          widget.counter,
                                          widget.counter.current + 1,
                                          'plus',
                                        ),
                                      ),
                                      if (widget.counter.threshold > 60)
                                        _ActionButton(
                                          label: '+10',
                                          color: accent,
                                          onTap: () => widget.onChange(
                                            widget.counter,
                                            widget.counter.current + 10,
                                            'plus10',
                                          ),
                                        ),
                                      _ActionButton(
                                        label: TranslationService.t('reset'),
                                        isReset: true,
                                        color: AppColors.red,
                                        onTap: () {
                                          widget.onChange(
                                            widget.counter,
                                            0,
                                            'reset',
                                          );
                                          widget.onResetAnimation?.call();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 42,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 84,
                                      height: 42,
                                      child: TextField(
                                        controller: _controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: AppColors.field
                                              .withValues(alpha: 0.5),
                                          contentPadding: EdgeInsets.zero,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: accent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onSubmitted: _submit,
                                        onEditingComplete: () =>
                                            _submit(_controller.text),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '/ ${widget.counter.threshold}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 44,
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chanceColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: chanceColor.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    widget.counter.chanceLabel,
                                    style: GoogleFonts.outfit(
                                      color: chanceColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: compact ? 12 : 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          _wasReset
              ? ScaleTransition(
                  alignment: Alignment.center,
                  scale: _resetScaleAnimation,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        TranslationService.t('win_text'),
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.isReset = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isReset;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        child: OutlinedButton(
          onPressed: widget.onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: _isHovered
                ? widget.color.withValues(alpha: 0.2)
                : Colors.transparent,
            side: BorderSide(
              color:
                  _isHovered ? widget.color : widget.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isReset ? 20 : 16,
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.outfit(
              color:
                  widget.color == AppColors.red ? AppColors.red : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
