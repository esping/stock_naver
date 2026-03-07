import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../models/news_item.dart';

class StorageService {
  static const _stocksKey = 'stocks';
  static const _newsKey = 'news';
  static const _allowedSourcesKey = 'allowed_sources';             // 허용 언론사 (화이트리스트)
  static const _discoveredCategoriesKey = 'discovered_categories'; // 수집된 카테고리 전체
  static const _excludedCategoriesKey = 'excluded_categories';     // 제외할 카테고리

  // 종목 목록 불러오기
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
    await prefs.setString(_stocksKey, jsonEncode(stocks.map((s) => s.toJson()).toList()));
  }

  // 뉴스 저장 (최대 2000개)
  static Future<void> saveNews(List<NewsItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final limited = items.take(2000).toList();
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

  // ── 언론사 관련 (화이트리스트) ────────────────────────

  // 허용 언론사 목록 불러오기 (비어있으면 전체 허용)
  static Future<Set<String>> loadAllowedSources() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_allowedSourcesKey)?.toSet() ?? {};
  }

  // 허용 언론사 저장
  static Future<void> saveAllowedSources(Set<String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allowedSourcesKey, sources.toList());
  }

  // ── 카테고리 관련 ─────────────────────────────────────

  // 수집 중 발견된 카테고리 전체 목록 (자동 누적)
  static Future<Set<String>> loadDiscoveredCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_discoveredCategoriesKey)?.toSet() ?? {};
  }

  // 수집 시 발견된 카테고리 추가 (누적)
  static Future<void> addDiscoveredCategories(Iterable<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final discovered = prefs.getStringList(_discoveredCategoriesKey)?.toSet() ?? {};
    discovered.addAll(categories.where((c) => c.isNotEmpty));
    await prefs.setStringList(_discoveredCategoriesKey, discovered.toList());
  }

  // 제외할 카테고리 불러오기
  static Future<Set<String>> loadExcludedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_excludedCategoriesKey)?.toSet() ?? {};
  }

  // 제외할 카테고리 저장
  static Future<void> saveExcludedCategories(Set<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_excludedCategoriesKey, categories.toList());
  }

  // 새 뉴스와 기존 뉴스 병합: 중복 제거 + 30일 이내 + 언론사 화이트리스트 + 카테고리 블랙리스트
  static List<NewsItem> mergeAndFilter(
    List<NewsItem> fresh,
    List<NewsItem> prev, {
    Set<String> allowedSources = const {},   // 비어있으면 전체 허용
    Set<String> excludedCategories = const {},
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final seenLinks = <String>{};
    return [...fresh, ...prev]
        .where((n) {
          if (!seenLinks.add(n.link)) return false;
          if (!n.publishedAt.isAfter(cutoff)) return false;
          if (allowedSources.isNotEmpty && !allowedSources.contains(n.source)) return false;
          if (n.category.isNotEmpty && excludedCategories.contains(n.category)) return false;
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
