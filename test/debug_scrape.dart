import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String baseUrl = "https://t.me/s/toooyaaa_s_channel";
  String currentUrl = baseUrl;
  
  print("Starting debug scrape...");
  
  Set<String> heroes = {};
  int iterations = 100; 

  for (int i = 0; i < iterations; i++) {
    print("Iteration $i: Fetching $currentUrl...");
    final response = await http.get(Uri.parse(currentUrl)).timeout(const Duration(seconds: 10));
    print("Status: ${response.statusCode}");
    if (response.statusCode != 200) {
      break;
    }

    final html = response.body;
    print("HTML length: ${html.length}");
    final messageRegex = RegExp(r'<div class="tgme_widget_message_wrap js-widget_message_wrap">(.*?)</div>\s*</div>\s*</div>', dotAll: true);
    final matches = messageRegex.allMatches(html);

    print("Found ${matches.length} messages");
    if (matches.isEmpty) break;

    int minId = 999999999;

    for (final m in matches) {
      final msgBody = m.group(1) ?? "";
      
      final idMatch = RegExp(r'data-post="toooyaaa_s_channel/(\d+)"').firstMatch(msgBody);
      if (idMatch != null) {
        final id = int.parse(idMatch.group(1)!);
        if (id < minId) minId = id;
      }

      if (msgBody.contains('%23%D0%9A%D0%B0%D0%BA%D0%9E%D0%B4%D0%B5%D1%82%D1%8C')) {
        final heroMatch = RegExp(r'q=%23([^"]+)"[^>]*>#([^<]+)').firstMatch(msgBody);
        if (heroMatch != null) {
          final name = heroMatch.group(2)!.trim();
          heroes.add(name);
          if (name.contains("Фре") || name.contains("Freya")) {
            print("FOUND CANDIDATE: $name (ID: $minId)");
          }
        }
      }
    }

    if (minId < 999999999 && minId > 1) {
      currentUrl = "$baseUrl?before=$minId";
    } else {
      break;
    }
  }

  print("\nTotal heroes found: ${heroes.length}");
  if (heroes.any((h) => h.contains("Фрейя"))) {
    print("SUCCESS: Фрейя is in the list!");
  } else {
    print("FAILURE: Фрейя not found.");
  }
}
