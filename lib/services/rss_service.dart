import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/news_item.dart';
import '../models/stock.dart';

class RssService {
  // knownKeywords: 이미 수집한 적 있는 키워드 → 1일치만 가져옴
  // 새 키워드는 30일치 가져옴
  static Future<List<NewsItem>> fetchAllNews(
    List<Stock> stocks, {
    Set<String> knownKeywords = const {},
  }) async {
    final allItems = <NewsItem>[];
    final seenLinks = <String>{};

    for (final stock in stocks) {
      for (final keyword in stock.keywords) {
        final isNew = !knownKeywords.contains(keyword);
        final daysBack = isNew ? 30 : 1;
        final items = await _fetchByKeyword(keyword, stock.name, daysBack: daysBack);
        for (final item in items) {
          if (seenLinks.add(item.link)) {
            allItems.add(item);
          }
        }
      }
    }

    allItems.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return allItems;
  }

  static Future<List<NewsItem>> _fetchByKeyword(
    String keyword,
    String stockName, {
    int daysBack = 1,
  }) async {
    final encoded = Uri.encodeComponent('$keyword when:${daysBack}d');
    final url = 'https://news.google.com/rss/search?q=$encoded&hl=ko&gl=KR&ceid=KR:ko';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      return _parseRss(response.body, stockName);
    } catch (_) {
      return [];
    }
  }

  static List<NewsItem> _parseRss(String xmlBody, String stockName) {
    final items = <NewsItem>[];
    try {
      final document = XmlDocument.parse(xmlBody);
      final entries = document.findAllElements('item');

      for (final entry in entries) {
        final title = entry.findElements('title').firstOrNull?.innerText ?? '';
        final link = entry.findElements('link').firstOrNull?.innerText ?? '';
        final pubDate = entry.findElements('pubDate').firstOrNull?.innerText ?? '';
        final source = entry.findElements('source').firstOrNull?.innerText ?? '';

        if (title.isEmpty || link.isEmpty) continue;

        items.add(NewsItem(
          title: title,
          link: link,
          source: source,
          publishedAt: _parseDate(pubDate),
          stockName: stockName,
        ));
      }
    } catch (_) {}
    return items;
  }

  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      try {
        return HttpDate.parse(raw);
      } catch (_) {
        return DateTime.now();
      }
    }
  }
}

// RFC 822 날짜 파싱 헬퍼
class HttpDate {
  static DateTime parse(String date) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final parts = date.split(' ');
    final day = int.parse(parts[1]);
    final month = months[parts[2]] ?? 1;
    final year = int.parse(parts[3]);
    final timeParts = parts[4].split(':');
    return DateTime.utc(year, month, day,
        int.parse(timeParts[0]), int.parse(timeParts[1]), int.parse(timeParts[2]));
  }
}
