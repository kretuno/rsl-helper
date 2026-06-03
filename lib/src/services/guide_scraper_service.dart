import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GuideScraperService {
  static const String baseUrl = "https://t.me/s/toooyaaa_s_channel";
  
  /// Путь к файлу с данными гайдов в документах приложения
  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/all_guides_data.json');
  }

  /// Основной метод парсинга (аналог super_scrape.ps1)
  static Future<int> refreshGuides() async {
    if (kIsWeb) return 0;
    List<dynamic> allGuides = [];
    
    // Пытаемся загрузить существующие данные из локального файла
    final file = await _localFile;
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        allGuides = json.decode(content);
      } catch (e) {
        allGuides = [];
      }
    }

    String currentUrl = baseUrl;
    int iterations = 150; // Увеличиваем до 150, чтобы дойти до старых постов
    int foundNew = 0;
    int duplicateStreak = 0;
    const int stopOnDuplicateStreak = 30; // Останавливаемся, если встретили 30 известных постов подряд

    for (int i = 0; i < iterations; i++) {
      final response = await http.get(Uri.parse(currentUrl));
      if (response.statusCode != 200) break;

      final html = response.body;
      
      // Регулярки для поиска сообщений
      final messageRegex = RegExp(r'<div class="tgme_widget_message_wrap js-widget_message_wrap">(.*?)</div>\s*</div>\s*</div>', dotAll: true);
      final matches = messageRegex.allMatches(html);

      if (matches.isEmpty) break;

      int minId = 999999999;

      for (final m in matches) {
        final msgBody = m.group(1) ?? "";
        
        // ID поста
        final idMatch = RegExp(r'data-post="toooyaaa_s_channel/(\d+)"').firstMatch(msgBody);
        if (idMatch == null) continue;
        final id = int.parse(idMatch.group(1)!);
        if (id < minId) minId = id;

        // Проверяем, есть ли тег #КакОдеть
        if (msgBody.contains('%23%D0%9A%D0%B0%D0%BA%D0%9E%D0%B4%D0%B5%D1%82%D1%8C')) {
          // Извлекаем URL картинки
          final imgMatch = RegExp(r"background-image:url\('([^']+)'\)").firstMatch(msgBody);
          if (imgMatch != null) {
            final imageUrl = imgMatch.group(1)!;
            
            // Ищем все хештеги в сообщении
            final allHashtags = RegExp(r'q=%23([^"]+)"[^>]*>#([^<]+)')
                .allMatches(msgBody)
                .map((m) => m.group(2)!.trim())
                .toList();

            // Исключаем технические теги, чтобы найти имя героя
            String? heroName;
            for (var tag in allHashtags) {
              final normalizedTag = tag.toLowerCase().replaceAll('_', '').trim();
              
              // Если тег содержит 'какодеть' или является техническим — пропускаем
              if (normalizedTag.contains('какодеть') || 
                  normalizedTag == 'raid' || 
                  normalizedTag == 'rsl' || 
                  normalizedTag == 'raidshadowlegends' ||
                  normalizedTag == 'рейд') {
                continue;
              }
              
              // Если мы здесь, значит это похоже на имя героя
              heroName = tag;
              break;
            }

            if (heroName != null) {
              // Ищем, есть ли уже такой ID в базе
              int existingIndex = allGuides.indexWhere((g) => g['Id'] == id);
              
              if (existingIndex == -1) {
                // Новая запись
                allGuides.add({
                  'Hero': heroName,
                  'ImageUrl': imageUrl,
                  'Id': id,
                  'PostLink': "https://t.me/toooyaaa_s_channel/$id"
                });
                foundNew++;
                duplicateStreak = 0;
              } else {
                // Запись уже есть, проверяем не нужно ли исправить имя
                String currentName = (allGuides[existingIndex]['Hero'] ?? '').toString().toLowerCase();
                if (currentName.contains('какодеть') || currentName == 'unknown' || currentName.isEmpty) {
                  allGuides[existingIndex]['Hero'] = heroName;
                  // Также обновляем ссылку на картинку на всякий случай
                  allGuides[existingIndex]['ImageUrl'] = imageUrl;
                }
                duplicateStreak++;
              }
            }
          }
        }
      }

      // Если мы долго не находим ничего нового — скорее всего, мы дошли до конца новых данных
      if (duplicateStreak >= stopOnDuplicateStreak) {
        break;
      }

      if (minId < 999999999 && minId > 1) {
        currentUrl = "$baseUrl?before=$minId";
      } else {
        break;
      }
      
      // Небольшая пауза между запросами
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Сохраняем результат (сортируем по имени героя)
    allGuides.sort((a, b) => (a['Hero'] as String).compareTo(b['Hero'] as String));
    await file.writeAsString(json.encode(allGuides));

    // Запускаем фоновое кэширование картинок
    cacheAllImages(allGuides);

    return foundNew;
  }

  /// Метод для получения данных (сначала из локального файла, потом из ассетов)
  static Future<String?> getGuidesJson() async {
    if (kIsWeb) return null;
    final file = await _localFile;
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  /// Сохраняет изображение в локальный кэш
  static Future<void> cacheImage(String imageUrl, int id) async {
    if (kIsWeb) return;
    try {
      if (imageUrl.isEmpty) return;
      final directory = await getApplicationDocumentsDirectory();
      final guidesDir = Directory('${directory.path}/guides');
      if (!await guidesDir.exists()) {
        await guidesDir.create(recursive: true);
      }
      final file = File('${guidesDir.path}/$id.jpg');
      if (await file.exists()) {
        return; // Уже скачано
      }
      
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Ошибка при кэшировании изображения $id: $e');
    }
  }

  /// Кэширует изображения для всех переданных гайдов по очереди
  static Future<void> cacheAllImages(List<dynamic> guides) async {
    if (kIsWeb) return;
    for (var item in guides) {
      final id = item['Id'];
      final imageUrl = item['ImageUrl'];
      if (id is int && imageUrl is String && imageUrl.isNotEmpty) {
        await cacheImage(imageUrl, id);
        // Небольшая пауза, чтобы не нагружать сеть/сервер
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }
}
