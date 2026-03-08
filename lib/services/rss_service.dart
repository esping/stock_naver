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
        String searchQuery;

        if (allowedSources.isEmpty) {
          // 언론사 지정이 없으면
          searchQuery = keyword;
        } else {
          // 등록된 언론사가 있으면 네이버 문법( | )을 활용하여 다중 검색
          final sourcesQuery = allowedSources.join('|');
          searchQuery = '$keyword +($sourcesQuery)';
        }

        final items = await _fetchByKeyword(searchQuery, stock.name);

        // 1회의 네트워크 응답을 받은 후, 내부(Dart) 로직으로 제외 키워드를 포함한 기사를 필터링
        for (final item in items) {
          if (excludedKeywords.isNotEmpty) {
            final lowerTitle = item.title.toLowerCase();
            final hasExcluded = excludedKeywords.any(
              (ex) => lowerTitle.contains(ex.toLowerCase()),
            );
            if (hasExcluded) continue; // 제외어가 제목에 포함되어 있다면 스킵
          }

          // Appended OR queries in Naver search already filter by newspaper name (e.g. '이데일리')
          // However, our item.source extracts the domain (e.g. 'edaily.co.kr').
          // To ensure we don't accidentally drop valid articles returned by Naver's advanced query,
          // we only apply a strict domain filter if we couldn't append them cleanly.
          // Since we are appending to the search query, we can trust Naver's result filtering more
          // and skip the rigid domain check here if we used the advanced query.

          final titleKey = '${item.title}_${item.source}';
          if (seenLinks.add(item.link) && seenTitles.add(titleKey)) {
            allItems.add(item);
          }
        }
      }
    }

    // Create a cutoff threshold of 24 hours ago (in UTC to match parsed HttpDates which return UTC)
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
    
    // 1st page (items 1 to 100) sorted by similarity to prioritize most relevant news
    final url1 = 'https://openapi.naver.com/v1/search/news.json?query=$encodedKeyword&display=100&start=1&sort=sim';
        
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
          
          // 2nd page (items 101 to 200) if more results exist
          if (total > 100) {
            final url2 = 'https://openapi.naver.com/v1/search/news.json?query=$encodedKeyword&display=100&start=101&sort=sim';
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
          print('Error checking total/fetching second page: $e');
        }
      }
    } catch (_) {
      // Ignored
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
        
        // Extract a simple domain name from originalLink to represent the source
        String source = '';
        if (originalLink.isNotEmpty) {
          try {
            final uri = Uri.parse(originalLink);
            source = uri.host.replaceFirst('www.', '');
          } catch (_) {}
        }

        if (source.isEmpty) {
          source = 'Naver News';
        }

        if (rawTitle.isEmpty || link.isEmpty) continue;

        // Strip HTML tags from title (e.g. <b>주식</b> -> 주식) and unescape
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
      print('Naver API parsing error: $e');
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

// RFC 822 날짜 파싱 헬퍼
class HttpDate {
  static DateTime parse(String date) {
    final months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final parts = date.split(' ');
    final day = int.parse(parts[1]);
    final month = months[parts[2]] ?? 1;
    final year = int.parse(parts[3]);
    final timeParts = parts[4].split(':');
    return DateTime.utc(
      year,
      month,
      day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }
}
