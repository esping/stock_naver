import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../models/news_item.dart';

class StorageService {
  static const _stocksKey = 'stocks_list';
  static const _allowedSourcesKey = 'allowed_sources'; // 허용된 언론사 목록
  static const _excludedKeywordsKey = 'excluded_keywords'; // 제외 키워드 목록

  // ── 종목 관련 ──────────────────────────────────────불러오기
  static Future<List<Stock>> loadStocks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stocksKey);
    if (raw == null) return _defaultStocks();
    final list = jsonDecode(raw) as List;
    return list.map((e) => Stock.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 종목 목록 저장
  static Future<void> saveStocks(List<Stock> stocks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stocksKey,
      jsonEncode(stocks.map((s) => s.toJson()).toList()),
    );
  }

  static Future<String> _getNewsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final newsDir = Directory('${dir.path}/news');
    if (!await newsDir.exists()) {
      await newsDir.create(recursive: true);
    }
    return newsDir.path;
  }

  // 뉴스 저장 (날짜별 분할 파일 형태, 30일 경과 파일 삭제)
  static Future<void> saveNews(List<NewsItem> items) async {
    final newsDir = await _getNewsDir();

    // 날짜별 그룹화 (YYYY-MM-DD 형식)
    final byDate = <String, List<NewsItem>>{};
    for (final item in items) {
      final dt = item.publishedAt.toLocal();
      final dateKey =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(dateKey, () => []).add(item);
    }

    // 각 그룹별 파일 쓰기 (기존 5000개 수량 제한 해제)
    for (final entry in byDate.entries) {
      final file = File('$newsDir/${entry.key}.json');
      await file.writeAsString(
        jsonEncode(entry.value.map((n) => n.toJson()).toList()),
      );
    }

    // 30일 경과 파일 자동 정리
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final dir = Directory(newsDir);
    final files = dir.listSync();
    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        final filename = file.uri.pathSegments.last.replaceAll('.json', '');
        try {
          final fileDate = DateTime.parse(filename);
          if (fileDate.isBefore(cutoff)) {
            await file.delete();
          }
        } catch (_) {} // 파일명 파싱 실패 시 무시
      }
    }
  }

  // 뉴스 불러오기 (특정 날짜 범위가 주어지지 않으면 전체 파일 읽기)
  static Future<List<NewsItem>> loadNews({List<String>? targetDates}) async {
    // [레거시 데이터 청소] 이전 버전에 쓰이던 단일 String _newsKey 삭제
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('saved_news')) {
      await prefs.remove('saved_news');
    }

    final newsDir = await _getNewsDir();
    final dir = Directory(newsDir);
    if (!await dir.exists()) return [];

    final allItems = <NewsItem>[];
    final files = dir.listSync();

    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        final filename = file.uri.pathSegments.last.replaceAll('.json', '');

        if (targetDates != null && !targetDates.contains(filename)) {
          continue; // 타겟 날짜 목록이 있고, 현재 파일이 속하지 않으면 스킵
        }

        try {
          final raw = await file.readAsString();
          final list = jsonDecode(raw) as List;
          allItems.addAll(
            list.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)),
          );
        } catch (_) {}
      }
    }

    allItems.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return allItems;
  }

  // ── 언론사/제외키워드 관리 ──────────────────────────

  static Future<Set<String>> loadAllowedSources() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_allowedSourcesKey);
    return saved?.toSet() ?? {'한국경제', '매일경제', '서울경제'};
  }

  static Future<void> saveAllowedSources(Set<String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allowedSourcesKey, sources.toList());
  }

  static Future<Set<String>> loadExcludedKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_excludedKeywordsKey);
    return saved?.toSet() ?? {};
  }

  static Future<void> saveExcludedKeywords(Set<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_excludedKeywordsKey, keywords.toList());
  }

  static Future<Set<String>> loadReadLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('read_links');
    return saved?.toSet() ?? {};
  }

  static Future<void> saveReadLinks(Set<String> links) async {
    final prefs = await SharedPreferences.getInstance();
    // 5000개 제한을 뉴스 최대 저장량과 동일하게 유지
    final limitedLinks = links.length > 5000
        ? links.toList().sublist(links.length - 5000).toSet()
        : links;
    await prefs.setStringList('read_links', limitedLinks.toList());
  }

  // ── 뉴스 데이터 (로컬 캐싱) ──────────────────────────병합: 중복 제거 + 30일 이내 + 언론사 화이트리스트
  static List<NewsItem> mergeAndFilter(
    List<NewsItem> fresh,
    List<NewsItem> prev, {
    Set<String> allowedSources = const {}, // 비어있으면 전체 허용
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final seenLinks = <String>{};
    final seenTitles = <String>{};

    return [...prev, ...fresh].where((n) {
      final titleKey = '${n.title}_${n.source}';
      if (!seenLinks.add(n.link)) return false;
      if (!seenTitles.add(titleKey)) return false;
      if (!n.publishedAt.isAfter(cutoff)) return false;
      if (allowedSources.isNotEmpty && !allowedSources.contains(n.source)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  // ── 고아 기사 정리 (종목/키워드 삭제 시 호출) ─────────────────────
  static Future<void> cleanUpOrphanedNews(List<Stock> currentStocks) async {
    final newsDir = await _getNewsDir();
    final dir = Directory(newsDir);
    if (!await dir.exists()) return;

    final validStockNames = currentStocks.map((s) => s.name).toSet();
    final files = dir.listSync();

    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final raw = await file.readAsString();
          final list = jsonDecode(raw) as List;
          final allNews = list
              .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
              .toList();

          final filteredNews = allNews.where((news) {
            return validStockNames.contains(news.stockName);
          }).toList();

          // 삭제된 기사가 있어서 파일 내용이 변했다면 덮어쓰기, 아예 다 지워졌으면 파일 삭제
          if (filteredNews.length != allNews.length) {
            if (filteredNews.isEmpty) {
              await file.delete();
            } else {
              await file.writeAsString(
                jsonEncode(filteredNews.map((n) => n.toJson()).toList()),
              );
            }
          }
        } catch (_) {}
      }
    }
  }

  static List<Stock> _defaultStocks() => [
    Stock(name: '삼성전자', keywords: ['삼성전자', 'Samsung Electronics']),
    Stock(name: 'SK하이닉스', keywords: ['SK하이닉스', '하이닉스', 'SK Hynix']),
  ];
}
