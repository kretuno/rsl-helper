import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/guide.dart';
import '../../services/translation_service.dart';
import '../../services/guide_scraper_service.dart';
import '../../theme/app_colors.dart';

class GuidesView extends StatefulWidget {
  const GuidesView({super.key});

  @override
  State<GuidesView> createState() => GuidesViewState();
}

class GuidesViewState extends State<GuidesView> {
  List<Guide> _allGuides = [];
  List<Guide> _filteredGuides = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadGuides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _processJson(String jsonString) async {
    final List<dynamic> jsonData = json.decode(jsonString);

    // Загружаем ассеты для сопоставления правильных имен
    List<dynamic> assetData = [];
    try {
      final assetJson = await rootBundle.loadString('assets/all_guides_data.json');
      assetData = json.decode(assetJson);
    } catch (e) {
      debugPrint('Error loading asset guides for repair: $e');
    }

    final Map<int, String> assetNames = {};
    for (var item in assetData) {
      final id = item['Id'];
      final hero = item['Hero'];
      if (id is int && hero is String) {
        assetNames[id] = hero;
      }
    }

    bool didRepair = false;
    final List<Guide> loadedGuides = [];

    for (var item in jsonData) {
      String heroName = item['Hero'] ?? 'Unknown';
      final int? id = item['Id'];

      if (id != null && (heroName.toLowerCase().contains('какодеть') || heroName == 'Unknown')) {
        if (assetNames.containsKey(id)) {
          heroName = assetNames[id]!;
          didRepair = true;
        }
      }

      final String safeHeroName =
          heroName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final String fileName = '$safeHeroName.jpg';

      loadedGuides.add(Guide(
        id: id,
        heroName: heroName,
        imageUrl: item['ImageUrl'] ?? '',
        telegramUrl: item['PostLink'] ?? 'https://t.me/toooyaaa_s_channel',
        assetPath: 'assets/guides/$fileName',
      ));
    }

    if (mounted) {
      setState(() {
        _allGuides = loadedGuides;
        _filteredGuides = _allGuides;
        _isLoading = false;
      });
    }

    if (didRepair) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/all_guides_data.json');
        
        final List<Map<String, dynamic>> saveList = _allGuides.map((g) => {
          'Hero': g.heroName,
          'ImageUrl': g.imageUrl,
          'Id': g.id,
          'PostLink': g.telegramUrl,
        }).toList();
        
        await file.writeAsString(json.encode(saveList));
        debugPrint('Repaired guides list successfully saved to disk.');
      } catch (e) {
        debugPrint('Error saving repaired guides to disk: $e');
      }
    }
  }

  void _triggerBackgroundCaching() {
    final guidesData = _allGuides.map((g) => {
      'Id': g.id,
      'ImageUrl': g.imageUrl,
    }).toList();
    GuideScraperService.cacheAllImages(guidesData);
  }

  Future<void> loadGuides() async {
    try {
      // Сначала пытаемся загрузить из локального файла (обновленного парсером)
      final localJson = await GuideScraperService.getGuidesJson();
      if (localJson != null) {
        await _processJson(localJson);
        _triggerBackgroundCaching();
        return;
      }

      // Если локального файла нет, грузим из ассетов
      final assetJson = await rootBundle.loadString('assets/all_guides_data.json');
      await _processJson(assetJson);
      _triggerBackgroundCaching();
    } catch (e) {
      debugPrint('Error loading guides: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterGuides(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGuides = _allGuides;
      } else {
        _filteredGuides = _allGuides
            .where((g) => g.heroName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationService.t('guides'),
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        TranslationService.t('library_raid')
                            .replaceAll('{count}', _allGuides.length.toString()),
                        style: GoogleFonts.inter(
                          color: AppColors.gold.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: isWide ? 320 : 220,
                height: 46,
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterGuides,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: TranslationService.t('search_guides'),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    prefixIcon: Icon(Icons.search_rounded, 
                        color: Colors.white.withValues(alpha: 0.2), size: 18),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_filteredGuides.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_outlined, color: Colors.white10, size: 80),
                    const SizedBox(height: 16),
                    Text(
                      TranslationService.t('guides_not_found'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white24),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.72,
                ),
                itemCount: _filteredGuides.length,
                itemBuilder: (context, index) => _GuideCard(guide: _filteredGuides[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatefulWidget {
  const _GuideCard({required this.guide});
  final Guide guide;

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _isHovered = false;
  File? _cachedFile;

  @override
  void initState() {
    super.initState();
    _checkLocalCache();
  }

  Future<void> _checkLocalCache() async {
    if (widget.guide.id == null) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/guides/${widget.guide.id}.jpg');
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _cachedFile = file;
          });
        }
      } else {
        _cacheImageInBackground();
      }
    } catch (e) {
      debugPrint('Error checking local image cache: $e');
    }
  }

  void _cacheImageInBackground() {
    if (widget.guide.id != null && widget.guide.imageUrl.isNotEmpty) {
      GuideScraperService.cacheImage(widget.guide.imageUrl, widget.guide.id!).then((_) {
        if (mounted) {
          _checkLocalCache();
        }
      });
    }
  }

  void _showFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5.0,
                child: Center(
                  child: _cachedFile != null
                      ? Image.file(
                          _cachedFile!,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            widget.guide.assetPath ?? '',
                            errorBuilder: (context, error, stackTrace) => Image.network(
                              widget.guide.imageUrl,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, color: Colors.white10, size: 120),
                            ),
                          ),
                        )
                      : Image.asset(
                          widget.guide.assetPath ?? '',
                          errorBuilder: (context, error, stackTrace) => Image.network(
                            widget.guide.imageUrl,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, color: Colors.white10, size: 120),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(30),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    widget.guide.heroName,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTelegram() async {
    final url = Uri.parse(widget.guide.telegramUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _showFullscreen(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..setTranslationRaw(0.0, _isHovered ? -8.0 : 0.0, 0.0),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered 
                  ? AppColors.gold.withValues(alpha: 0.3) 
                  : Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.4 : 0.2),
                blurRadius: _isHovered ? 20 : 12,
                offset: Offset(0, _isHovered ? 12 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _cachedFile != null
                          ? Image.file(
                              _cachedFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Image.asset(
                                widget.guide.assetPath ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.network(
                                  widget.guide.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    child: const Icon(Icons.broken_image, color: Colors.white10, size: 48),
                                  ),
                                ),
                              ),
                            )
                          : Image.asset(
                              widget.guide.assetPath ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Image.network(
                                widget.guide.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  child: const Icon(Icons.broken_image, color: Colors.white10, size: 48),
                                ),
                              ),
                            ),
                    ),
                    if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.guide.heroName,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _isHovered ? AppColors.gold : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _openTelegram,
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: const Text('Telegram'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white60,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: _isHovered ? AppColors.gold : Colors.white24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
