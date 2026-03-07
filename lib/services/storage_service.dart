import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../models/news_item.dart';

class StorageService {
  static const _stocksKey = 'stocks';
  static const _newsKey = 'news';
  static const _allowedSourcesKey = 'allowed_sources';   // 허용 언론사 (화이트리스트)
  static const _enabledSectionsKey = 'enabled_sections'; // 수집할 섹션

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

  // ── 섹션 관련 ─────────────────────────────────────────

  // 수집할 섹션 목록 (기본: BUSINESS, TECHNOLOGY)
  static Future<Set<String>> loadEnabledSections() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_enabledSectionsKey);
    if (saved == null) return {'BUSINESS', 'TECHNOLOGY'};
    return saved.toSet();
  }

  // 수집할 섹션 저장
  static Future<void> saveEnabledSections(Set<String> sections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_enabledSectionsKey, sections.toList());
  }

  // 새 뉴스와 기존 뉴스 병합: 중복 제거 + 30일 이내 + 언론사 화이트리스트
  static List<NewsItem> mergeAndFilter(
    List<NewsItem> fresh,
    List<NewsItem> prev, {
    Set<String> allowedSources = const {}, // 비어있으면 전체 허용
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final seenLinks = <String>{};
    return [...fresh, ...prev]
        .where((n) {
          if (!seenLinks.add(n.link)) return false;
          if (!n.publishedAt.isAfter(cutoff)) return false;
          if (allowedSources.isNotEmpty && !allowedSources.contains(n.source)) return false;
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
