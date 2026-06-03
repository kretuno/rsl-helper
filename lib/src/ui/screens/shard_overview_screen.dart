import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/shard_store.dart';
import '../../data/default_counters.dart';
import '../../models/history_entry.dart';
import '../../models/shard_counter.dart';
import '../../services/translation_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/counter_card.dart';
import '../widgets/history_list.dart';
import '../widgets/auth_dialog.dart';
import 'guides_view.dart';
import '../../services/guide_scraper_service.dart';

class ShardOverviewScreen extends StatefulWidget {
  const ShardOverviewScreen({super.key});

  @override
  State<ShardOverviewScreen> createState() => _ShardOverviewScreenState();
}

class _ShardOverviewScreenState extends State<ShardOverviewScreen> {
  final _store = ShardStore();
  late List<ShardCounter> _counters = defaultCounters();
  List<HistoryEntry> _history = const [];
  bool _isLoading = true;
  bool _showHistory = false;
  int _selectedTab = 0; // 0: Counters, 1: Guides
  final Map<String, GlobalKey<CounterCardState>> _cardKeys = {};
  StreamSubscription<User?>? _authSubscription;

  final GlobalKey<GuidesViewState> _guidesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
    if (_store.isFirebaseSupported) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted) {
          setState(() {});
          if (user != null) {
            _store.syncLocalToCloud().then((_) => _load());
          } else {
            _load();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onLanguageChanged(Language lang) {
    setState(() {
      TranslationService.currentLanguage = lang;
      _counters = defaultCounters(); // Re-initialize with translated titles/descriptions
      _load(); // Reload data to apply to counters
    });
  }

  Future<void> _refreshGuides() async {
    setState(() => _isLoading = true);
    try {
      final count = await GuideScraperService.refreshGuides();
      
      if (_guidesKey.currentState != null) {
        await _guidesKey.currentState!.loadGuides();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0 
                ? TranslationService.t('refresh_success_count').replaceAll('{0}', '$count')
                : TranslationService.t('refresh_success_no_new'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${TranslationService.t('refresh_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _load() async {
    try {
      final snapshot = await _store.load();
      if (snapshot != null && mounted) {
        setState(() {
          _counters = defaultCounters()
              .map(
                (counter) =>
                    counter.copyWith(current: snapshot.currents[counter.id]),
              )
              .toList();
          _history = snapshot.history;
        });
      }
    } catch (e) {
      // Error loading state
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() => _store.save(_counters, _history);

  void _changeCounter(ShardCounter counter, int value, String action) {
    final before = counter.current;
    final after = value.clamp(0, counter.threshold).toInt();
    final isReset = action == 'reset';

    if (before == after && !isReset) {
      return;
    }

    if (isReset) {
      _triggerCardReset(counter.id);
    }

    final nextHistory = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}_${counter.id}',
      counterId: counter.id,
      action: action,
      delta: after - before,
      before: before,
      after: after,
      createdAt: DateTime.now(),
    );
    setState(() {
      _counters = _counters
          .map(
            (item) =>
                item.id == counter.id ? item.copyWith(current: after) : item,
          )
          .toList();
      _history = [nextHistory, ..._history].take(300).toList();
    });
    _save();
  }

  void _triggerCardReset(String counterId) {
    _cardKeys[counterId]?.currentState?.triggerResetAnimation();
  }

  void _showHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        expand: false,
        builder: (context, controller) => HistoryList(
          history: _history,
          counters: _counters,
          controller: controller,
        ),
      ),
    );
  }

  void _showAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(
          'RSL Shard Memory ${packageInfo.version}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(
            TranslationService.t('app_info_text'),
            style: GoogleFonts.inter(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              TranslationService.t('close'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDonationUrl() async {
    final url = Uri.parse('https://send.monobank.ua/jar/mHTsyv3bB');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _exportData() async {
    final payload = ShardStore.encode(_counters, _history);
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final fileName =
        'rsl-shard-memory-${now.year}-${two(now.month)}-${two(now.day)}.json';
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: TranslationService.t('export'),
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(payload)),
      lockParentWindow: true,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null
              ? TranslationService.t('export_cancelled')
              : TranslationService.t('export_success').replaceAll('{0}', savedPath),
        ),
      ),
    );
  }

  void _onCloudPressed() async {
    if (!_store.isFirebaseSupported) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(
            TranslationService.t('cloud_sync'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            TranslationService.t('sync_windows_not_supported'),
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                TranslationService.t('close'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final url = Uri.parse('https://kretuno.github.io/rsl-helper/');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                TranslationService.t('sync_button_open_web'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(
            TranslationService.t('cloud_sync'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            TranslationService.t('sync_connected_as').replaceAll('{0}', user.email ?? ''),
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                TranslationService.t('close'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        TranslationService.currentLanguage == Language.ru
                            ? 'Вышли из аккаунта.'
                            : TranslationService.currentLanguage == Language.uk
                                ? 'Вийшли з акаунту.'
                                : 'Logged out.',
                      ),
                    ),
                  );
                }
              },
              child: Text(
                TranslationService.t('sync_logout'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final success = await showDialog<bool>(
        context: context,
        builder: (context) => const AuthDialog(),
      );

      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.t('sync_success'))),
        );
      }
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: TranslationService.t('import'),
      type: FileType.custom,
      allowedExtensions: const ['json'],
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    try {
      final String jsonContent;
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          throw const FormatException('Empty file');
        }
        jsonContent = utf8.decode(bytes);
      } else {
        final path = result.files.single.path;
        if (path == null) return;
        jsonContent = await File(path).readAsString();
      }
      final snapshot = ShardStore.decode(jsonContent);
      if (snapshot.currents.isEmpty) {
        throw const FormatException('Файл не содержит счетчики.');
      }
      if (!mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(
            TranslationService.t('import_confirm_title'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            TranslationService.t('import_confirm_content')
                .replaceAll('{0}', '${snapshot.currents.length}')
                .replaceAll('{1}', '${snapshot.history.length}'),
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                TranslationService.t('cancel'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                TranslationService.t('import'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      setState(() {
        _counters = defaultCounters()
            .map(
              (counter) =>
                  counter.copyWith(current: snapshot.currents[counter.id]),
            )
            .toList();
        _history = snapshot.history;
      });
      await _save();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(TranslationService.t('data_imported'))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${TranslationService.t('import_failed')}: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : Column(
                  children: [
                    kIsWeb
                        ? _TopBar(
                            selectedTab: _selectedTab,
                            onTabChanged: (index) =>
                                setState(() => _selectedTab = index),
                            showHistory: _showHistory,
                            onHistoryPressed: isWide
                                ? () => setState(() => _showHistory = !_showHistory)
                                : _showHistorySheet,
                            onInfoPressed: _showAppInfo,
                            onDonatePressed: _openDonationUrl,
                            onImportPressed: _importData,
                            onExportPressed: _exportData,
                            onLanguageChanged: _onLanguageChanged,
                            onRefreshPressed: _refreshGuides,
                            isCloudSupported: _store.isFirebaseSupported,
                            isCloudLoggedIn: _store.isFirebaseSupported && FirebaseAuth.instance.currentUser != null,
                            cloudUserEmail: _store.isFirebaseSupported ? FirebaseAuth.instance.currentUser?.email : null,
                            onCloudPressed: _onCloudPressed,
                          )
                        : DragToMoveArea(
                            child: _TopBar(
                        selectedTab: _selectedTab,
                        onTabChanged: (index) =>
                            setState(() => _selectedTab = index),
                        showHistory: _showHistory,
                        onHistoryPressed: isWide
                            ? () => setState(() => _showHistory = !_showHistory)
                            : _showHistorySheet,
                        onInfoPressed: _showAppInfo,
                        onDonatePressed: _openDonationUrl,
                        onImportPressed: _importData,
                        onExportPressed: _exportData,
                        onLanguageChanged: _onLanguageChanged,
                        onRefreshPressed: _refreshGuides,
                        isCloudSupported: _store.isFirebaseSupported,
                        isCloudLoggedIn: _store.isFirebaseSupported && FirebaseAuth.instance.currentUser != null,
                        cloudUserEmail: _store.isFirebaseSupported ? FirebaseAuth.instance.currentUser?.email : null,
                        onCloudPressed: _onCloudPressed,
                      ),
                    ),
                    Expanded(
                      child: _selectedTab == 0
                          ? (isWide
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 300,
                                        child: _CounterSidebar(
                                          counters: _counters,
                                        ),
                                      ),
                                      Expanded(
                                        child: _CounterWorkspace(
                                          counters: _counters,
                                          cardKeys: _cardKeys,
                                          onChange: _changeCounter,
                                        ),
                                      ),
                                      if (_showHistory)
                                        SizedBox(
                                          width: 360,
                                          child: HistoryList(
                                            history: _history,
                                            counters: _counters,
                                          ),
                                        ),
                                    ],
                                  )
                                : _MobileWorkspace(
                                    counters: _counters,
                                    cardKeys: _cardKeys,
                                    history: _history,
                                    onChange: _changeCounter,
                                  ))
                          : GuidesView(key: _guidesKey),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final bool showHistory;
  final VoidCallback onHistoryPressed;
  final VoidCallback onInfoPressed;
  final VoidCallback onDonatePressed;
  final VoidCallback onImportPressed;
  final VoidCallback onExportPressed;
  final ValueChanged<Language> onLanguageChanged;
  final VoidCallback onRefreshPressed;
  final bool isCloudSupported;
  final bool isCloudLoggedIn;
  final String? cloudUserEmail;
  final VoidCallback onCloudPressed;

  const _TopBar({
    required this.selectedTab,
    required this.onTabChanged,
    required this.showHistory,
    required this.onHistoryPressed,
    required this.onInfoPressed,
    required this.onDonatePressed,
    required this.onImportPressed,
    required this.onExportPressed,
    required this.onLanguageChanged,
    required this.onRefreshPressed,
    required this.isCloudSupported,
    required this.isCloudLoggedIn,
    required this.cloudUserEmail,
    required this.onCloudPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.6),
            border: const Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              _TabButton(
                label: TranslationService.t('counters'),
                icon: Icons.analytics_outlined,
                isActive: selectedTab == 0,
                onPressed: () => onTabChanged(0),
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: TranslationService.t('guides'),
                icon: Icons.auto_stories_outlined,
                isActive: selectedTab == 1,
                onPressed: () => onTabChanged(1),
              ),
              const Spacer(),
              if (selectedTab == 1)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _TopAction(
                    icon: Icons.refresh_rounded,
                    onPressed: onRefreshPressed,
                    tooltip: TranslationService.t('refresh_guides'),
                  ),
                ),
              _LanguagePicker(
                current: TranslationService.currentLanguage,
                onChanged: onLanguageChanged,
              ),
              const SizedBox(width: 4),
              _TopAction(
                icon: !isCloudSupported
                    ? Icons.cloud_off_rounded
                    : (isCloudLoggedIn ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded),
                color: !isCloudSupported
                    ? Colors.white.withOpacity(0.3)
                    : (isCloudLoggedIn ? AppColors.gold : Colors.white.withOpacity(0.7)),
                onPressed: onCloudPressed,
                tooltip: !isCloudSupported
                    ? TranslationService.t('sync_windows_not_supported')
                    : (isCloudLoggedIn
                        ? TranslationService.t('sync_connected_as').replaceAll('{0}', cloudUserEmail ?? '')
                        : TranslationService.t('cloud_sync')),
              ),
              _TopAction(
                icon: Icons.history_rounded,
                onPressed: onHistoryPressed,
                isActive: showHistory,
                tooltip: TranslationService.t('history'),
              ),
              _TopAction(
                icon: Icons.file_upload_outlined,
                onPressed: onImportPressed,
                tooltip: TranslationService.t('import'),
              ),
              _TopAction(
                icon: Icons.file_download_outlined,
                onPressed: onExportPressed,
                tooltip: TranslationService.t('export'),
              ),
              _TopAction(
                icon: Icons.favorite_border_rounded,
                onPressed: onDonatePressed,
                color: AppColors.red.withValues(alpha: 0.8),
                tooltip: TranslationService.t('help_project'),
              ),
              _TopAction(
                icon: Icons.info_outline_rounded,
                onPressed: onInfoPressed,
                tooltip: TranslationService.t('about_app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isActive;
  final String tooltip;

  const _TopAction({
    required this.icon,
    required this.onPressed,
    this.color,
    this.isActive = false,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: isActive ? AppColors.gold : (color ?? Colors.white.withValues(alpha: 0.7)),
            size: 22,
          ),
          style: IconButton.styleFrom(
            backgroundColor: isActive ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
            hoverColor: (color ?? Colors.white).withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final Language current;
  final ValueChanged<Language> onChanged;

  const _LanguagePicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Language>(
      initialValue: current,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      color: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              current.name.toUpperCase(),
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: Language.ru, child: Text('🇷🇺 RU')),
        const PopupMenuItem(value: Language.uk, child: Text('🇺🇦 UK')),
        const PopupMenuItem(value: Language.en, child: Text('🇺🇸 EN')),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? AppColors.gold : AppColors.muted),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterSidebar extends StatelessWidget {
  const _CounterSidebar({required this.counters});

  final List<ShardCounter> counters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 24),
            child: Text(
              TranslationService.t('shard_overview'),
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: -0.5,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: counters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _SidebarTile(counter: counters[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.counter});

  final ShardCounter counter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: counter.accentColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.panel.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: counter.accentColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: counter.accentColor.withValues(alpha: 0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Image.asset(counter.assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counter.title,
                  style: GoogleFonts.outfit(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${counter.current} ${TranslationService.t('shards_opened')}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterWorkspace extends StatelessWidget {
  const _CounterWorkspace({
    required this.counters,
    required this.cardKeys,
    required this.onChange,
  });

  final List<ShardCounter> counters;
  final Map<String, GlobalKey<CounterCardState>> cardKeys;
  final void Function(ShardCounter counter, int value, String action) onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationService.t('fail_compensation'),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: counters.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 415,
                mainAxisExtent: 420,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final id = counters[index].id;
                cardKeys[id] ??= GlobalKey<CounterCardState>();
                return CounterCard(
                  key: cardKeys[id],
                  counter: counters[index],
                  onChange: onChange,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileWorkspace extends StatelessWidget {
  const _MobileWorkspace({
    required this.counters,
    required this.cardKeys,
    required this.history,
    required this.onChange,
  });

  final List<ShardCounter> counters;
  final Map<String, GlobalKey<CounterCardState>> cardKeys;
  final List<HistoryEntry> history;
  final void Function(ShardCounter counter, int value, String action) onChange;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final counter in counters) ...[
          CounterCard(
            key: cardKeys[counter.id] ??= GlobalKey<CounterCardState>(),
            counter: counter,
            onChange: onChange,
          ),
          const SizedBox(height: 16),
        ],
        HistoryList(
          history: history,
          counters: counters,
          compact: true,
        ),
      ],
    );
  }
}
