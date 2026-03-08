import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import '../models/news_item.dart';
import '../models/stock.dart';

class RssService {
  static Future<List<NewsItem>> fetchAllNews(
    List<Stock> stocks, {
    Set<String> allowedSources = const {},
    Set<String> excludedKeywords = const {},
  }) async {
    if (stocks.isEmpty) return [];

    final allItems = <NewsItem>[];
    final seenLinks = <String>{};
    final seenTitles = <String>{};

    for (final stock in stocks) {
      for (final keyword in stock.keywords) {
        // 언론사명을 쿼리에 포함하면 출처 필터가 아닌 본문 텍스트 검색이 되어
        // 신문사명이 언급된 오래된 사설 모음 기사만 반환되는 문제가 있음.
        // 따라서 키워드만으로 검색하고, 언론사 필터는 fetch 후 도메인 기반으로 적용.
        final items = await _fetchByKeyword(keyword, stock.name);

        for (final item in items) {
          if (excludedKeywords.isNotEmpty) {
            final lowerTitle = item.title.toLowerCase();
            final hasExcluded = excludedKeywords.any(
              (ex) => lowerTitle.contains(ex.toLowerCase()),
            );
            if (hasExcluded) continue;
          }

          final titleKey = '${item.title}_${item.source}';
          if (seenLinks.add(item.link) && seenTitles.add(titleKey)) {
            allItems.add(item);
          }
        }
      }
    }

    // 24시간 이내 기사만 유지
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    allItems.removeWhere((item) => item.publishedAt.toUtc().isBefore(cutoff));
    allItems.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return allItems;
  }

  static Future<List<NewsItem>> _fetchByKeyword(
    String keyword,
    String stockName,
  ) async {
    final encodedKeyword = Uri.encodeComponent(keyword);
    final items = <NewsItem>[];

    // 최신 기사 우선 수집 (sort=date)
    final url1 = 'https://openapi.naver.com/v1/search/news.json?query=$encodedKeyword&display=100&start=1&sort=date';

    try {
      final response1 = await http.get(
        Uri.parse(url1),
        headers: {
          'X-Naver-Client-Id': '1bYt64mfI_HwbOP4oqai',
          'X-Naver-Client-Secret': 'cJPqOkVZd6',
        },
      ).timeout(const Duration(seconds: 10));

      if (response1.statusCode == 200) {
        items.addAll(_parseNaverJson(response1.body, stockName));

        try {
          final decoded = jsonDecode(response1.body) as Map<String, dynamic>;
          final total = decoded['total'] as int? ?? 0;

          if (total > 100) {
            final url2 = 'https://openapi.naver.com/v1/search/news.json?query=$encodedKeyword&display=100&start=101&sort=date';
            final response2 = await http.get(
              Uri.parse(url2),
              headers: {
                'X-Naver-Client-Id': '1bYt64mfI_HwbOP4oqai',
                'X-Naver-Client-Secret': 'cJPqOkVZd6',
              },
            ).timeout(const Duration(seconds: 10));

            if (response2.statusCode == 200) {
              items.addAll(_parseNaverJson(response2.body, stockName));
            }
          }
        } catch (e) {
          // 2페이지 처리 실패 시 1페이지 결과만 사용
        }
      }
    } catch (_) {
      // 네트워크 오류 시 빈 결과 반환
    }

    return items;
  }

  static List<NewsItem> _parseNaverJson(String jsonBody, String stockName) {
    final items = <NewsItem>[];
    final unescape = HtmlUnescape();

    try {
      final decoded = jsonDecode(jsonBody) as Map<String, dynamic>;
      final jsonItems = decoded['items'] as List<dynamic>? ?? [];

      for (final entry in jsonItems) {
        final rawTitle = entry['title']?.toString() ?? '';
        final link = entry['link']?.toString() ?? '';
        final pubDate = entry['pubDate']?.toString() ?? '';
        final originalLink = entry['originallink']?.toString() ?? '';

        // originalLink 에서 도메인 추출 (언론사 식별용)
        String source = '';
        if (originalLink.isNotEmpty) {
          try {
            final uri = Uri.parse(originalLink);
            source = uri.host.replaceFirst('www.', '');
          } catch (_) {}
        }
        if (source.isEmpty) source = 'Naver News';

        if (rawTitle.isEmpty || link.isEmpty) continue;

        // HTML 태그 제거 및 엔티티 디코딩
        var title = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '');
        title = unescape.convert(title);

        items.add(
          NewsItem(
            title: title,
            link: link,
            source: source,
            publishedAt: _parseDate(pubDate),
            stockName: stockName,
          ),
        );
      }
    } catch (e) {
      // 파싱 실패 시 빈 결과 반환
    }
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

// RFC 822 날짜 파싱 헬퍼 (Naver API pubDate 형식: "Sun, 08 Mar 2026 19:12:00 +0900")
class HttpDate {
  static DateTime parse(String date) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
      'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
      'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final parts = date.split(' ');
    final day = int.parse(parts[1]);
    final month = months[parts[2]] ?? 1;
    final year = int.parse(parts[3]);
    final timeParts = parts[4].split(':');
    return DateTime.utc(
      year, month, day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }
}
