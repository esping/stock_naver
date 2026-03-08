import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../models/news_item.dart';

class StorageService {
  static const _stocksKey = 'stocks_list';
  static const _newsKey = 'saved_news';
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

  // 뉴스 저장 (최대 5000개: 개수 초과 시 가장 오래된 데이터부터 삭제)
  static Future<void> saveNews(List<NewsItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    // items는 이미 최신순(내림차순)으로 정렬되어 있으므로,
    // take(5000)을 하면 최신 5000개만 유지되고 가장 오래된 데이터가 자연스럽게 삭제됩니다.
    final limited = items.take(5000).toList();
    await prefs.setString(
      _newsKey,
      jsonEncode(limited.map((n) => n.toJson()).toList()),
    );
  }

  // 뉴스 불러오기
  static Future<List<NewsItem>> loadNews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_newsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 언론사/제외키워드 관리 ──────────────────────────

  static Future<Set<String>> loadAllowedSources() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_allowedSourcesKey);
    return saved?.toSet() ?? {'한국경제', '매일경제'};
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

  // ── 뉴스 데이터 (로컬 캐싱) ──────────────────────────병합: 중복 제거 + 30일 이내 + 언론사 화이트리스트
  static List<NewsItem> mergeAndFilter(
    List<NewsItem> fresh,
    List<NewsItem> prev, {
    Set<String> allowedSources = const {}, // 비어있으면 전체 허용
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final seenLinks = <String>{};
    final seenTitles = <String>{};

    return [...fresh, ...prev].where((n) {
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_newsKey);
    if (raw == null) return;

    final list = jsonDecode(raw) as List;
    final allNews = list
        .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // 현재 저장된 모든(종목명 + 개별키워드) 허용 검색어 풀 생성
    // (뉴스는 stockName이 종목명, 검색당시 keyword를 명시적으로 가지고 있지 않으므로
    // 최소한 stockName은 현재 종목 리스트 안에 존재해야 함)
    final validStockNames = currentStocks.map((s) => s.name).toSet();

    final filteredNews = allNews.where((news) {
      if (!validStockNames.contains(news.stockName)) {
        return false;
      }
      return true;
    }).toList();

    // 정리된 뉴스 목록을 상한에 맞게 다시 저장
    final limited = filteredNews.take(5000).toList();
    await prefs.setString(
      _newsKey,
      jsonEncode(limited.map((n) => n.toJson()).toList()),
    );
  }

  static List<Stock> _defaultStocks() => [
    Stock(name: '삼성전자', keywords: ['삼성전자', 'Samsung Electronics']),
    Stock(name: 'SK하이닉스', keywords: ['SK하이닉스', '하이닉스', 'SK Hynix']),
  ];
}
