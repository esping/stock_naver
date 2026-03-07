import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/news_item.dart';
import '../models/stock.dart';

// 제공 섹션 목록 (key → 한국어 표시명)
const Map<String, String> kGoogleNewsSections = {
  'BUSINESS': '비즈니스',
  'TECHNOLOGY': 'IT·과학',
  'NATION': '국내',
  'WORLD': '세계',
  'ENTERTAINMENT': '연예',
  'SPORTS': '스포츠',
  'SCIENCE': '과학',
  'HEALTH': '건강',
};

class RssService {
  static Future<List<NewsItem>> fetchAllNews(
    List<Stock> stocks, {
    Set<String> enabledSections = const {},
  }) async {
    if (stocks.isEmpty || enabledSections.isEmpty) return [];

    final allItems = <NewsItem>[];
    final seenLinks = <String>{};

    for (final sectionKey in enabledSections) {
      final sectionName = kGoogleNewsSections[sectionKey] ?? sectionKey;
      final items = await _fetchBySection(sectionKey, sectionName, stocks);
      for (final item in items) {
        if (seenLinks.add(item.link)) {
          allItems.add(item);
        }
      }
    }

    // 섹션에서 기사가 없는 종목은 키워드 검색(7일치)으로 폴백
    final stocksWithArticles = allItems.map((n) => n.stockName).toSet();
    for (final stock in stocks) {
      if (stocksWithArticles.contains(stock.name)) continue;
      for (final keyword in stock.keywords) {
        final items = await _fetchByKeyword(keyword, stock.name);
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
    String stockName,
  ) async {
    final encodedKeyword = Uri.encodeComponent(keyword);
    final url =
        'https://news.google.com/rss/search?q=$encodedKeyword+when:7d&hl=ko&gl=KR&ceid=KR:ko';
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      return _parseRss(response.body, '', [Stock(name: stockName, keywords: [keyword])]);
    } catch (_) {
      return [];
    }
  }

  static Future<List<NewsItem>> _fetchBySection(
    String sectionKey,
    String sectionName,
    List<Stock> stocks,
  ) async {
    final url =
        'https://news.google.com/rss/headlines/section/topic/$sectionKey?hl=ko&gl=KR&ceid=KR:ko';

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      return _parseRss(response.body, sectionName, stocks);
    } catch (_) {
      return [];
    }
  }

  static List<NewsItem> _parseRss(
    String xmlBody,
    String sectionName,
    List<Stock> stocks,
  ) {
    final items = <NewsItem>[];
    try {
      final document = XmlDocument.parse(xmlBody);
      final entries = document.findAllElements('item');

      for (final entry in entries) {
        final title = entry.findElements('title').firstOrNull?.innerText ?? '';
        final link = entry.findElements('link').firstOrNull?.innerText ?? '';
        final pubDate =
            entry.findElements('pubDate').firstOrNull?.innerText ?? '';
        final source =
            entry.findElements('source').firstOrNull?.innerText ?? '';

        if (title.isEmpty || link.isEmpty) continue;

        final publishedAt = _parseDate(pubDate);

        // 어떤 종목 키워드가 제목에 포함되는지 확인
        for (final stock in stocks) {
          final matched = stock.keywords.any((kw) => title.contains(kw));
          if (matched) {
            items.add(NewsItem(
              title: title,
              link: link,
              source: source,
              section: sectionName,
              publishedAt: publishedAt,
              stockName: stock.name,
            ));
          }
        }
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
