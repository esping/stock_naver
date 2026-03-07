import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../models/news_item.dart';

class StorageService {
  static const _stocksKey = 'stocks';
  static const _newsKey = 'news';
  static const _knownKeywordsKey = 'known_keywords';
  static const _discoveredSourcesKey = 'discovered_sources'; // 수집된 언론사 전체
  static const _excludedSourcesKey = 'excluded_sources';     // 제외할 언론사

  // 종목 목록 불러오기
  static Future<List<Stock>> loadStocks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stocksKey);
    if (raw == null) return _defaultStocks();
    final list = jsonDecode(raw) as List;
    return list.map((e) => Stock.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 종목 목록 저장 (삭제된 키워드는 knownKeywords에서도 제거)
  static Future<void> saveStocks(List<Stock> stocks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stocksKey, jsonEncode(stocks.map((s) => s.toJson()).toList()));

    // 현재 종목에 없는 키워드는 known에서 제거 (재추가 시 신규로 처리)
    final currentKeywords = stocks.expand((s) => s.keywords).toSet();
    final known = prefs.getStringList(_knownKeywordsKey)?.toSet() ?? {};
    final filtered = known.intersection(currentKeywords);
    await prefs.setStringList(_knownKeywordsKey, filtered.toList());
  }

  // 이미 수집한 적 있는 키워드 목록 불러오기
  static Future<Set<String>> loadKnownKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_knownKeywordsKey)?.toSet() ?? {};
  }

  // 수집 완료된 키워드 등록
  static Future<void> addKnownKeywords(Iterable<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    final known = prefs.getStringList(_knownKeywordsKey)?.toSet() ?? {};
    known.addAll(keywords);
    await prefs.setStringList(_knownKeywordsKey, known.toList());
  }

  // 뉴스 저장 (최대 200개)
  static Future<void> saveNews(List<NewsItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final limited = items.take(200).toList();
    await prefs.setString(_newsKey, jsonEncode(limited.map((n) => n.toJson()).toList()));
  }

  // 뉴스 불러오기
  static Future<List<NewsItem>> loadNews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_newsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── 언론사 관련 ──────────────────────────────────────

  // 수집 중 발견된 언론사 전체 목록 (자동 누적)
  static Future<Set<String>> loadDiscoveredSources() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_discoveredSourcesKey)?.toSet() ?? {};
  }

  // 수집 시 발견된 언론사 추가 (누적)
  static Future<void> addDiscoveredSources(Iterable<String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final discovered = prefs.getStringList(_discoveredSourcesKey)?.toSet() ?? {};
    discovered.addAll(sources.where((s) => s.isNotEmpty));
    await prefs.setStringList(_discoveredSourcesKey, discovered.toList());
  }

  // 제외할 언론사 불러오기
  static Future<Set<String>> loadExcludedSources() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_excludedSourcesKey)?.toSet() ?? {};
  }

  // 제외할 언론사 저장
  static Future<void> saveExcludedSources(Set<String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_excludedSourcesKey, sources.toList());
  }

  // 새 뉴스와 기존 뉴스 병합: 중복 제거 + 30일 이내 + 제외 언론사 필터
  static List<NewsItem> mergeAndFilter(
    List<NewsItem> fresh,
    List<NewsItem> prev, {
    Set<String> excludedSources = const {},
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final seenLinks = <String>{};
    return [...fresh, ...prev]
        .where((n) {
          if (!seenLinks.add(n.link)) return false;
          if (!n.publishedAt.isAfter(cutoff)) return false;
          if (excludedSources.contains(n.source)) return false;
          return true;
        })
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  static List<Stock> _defaultStocks() => [
        Stock(name: '삼성전자', keywords: ['삼성전자', 'Samsung Electronics']),
        Stock(name: 'SK하이닉스', keywords: ['SK하이닉스', '하이닉스', 'SK Hynix']),
      ];
}
