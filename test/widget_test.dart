import 'package:flutter_test/flutter_test.dart';
import 'package:stock_naver/models/stock.dart';
import 'package:stock_naver/services/rss_service.dart';

void main() {
  test('Naver News API test - 현대차 (언론사 필터 있음)', () async {
    final stocks = [
      Stock(name: '현대차', keywords: ['현대차']),
    ];
    const allowedSources = {'서울경제', '매일경제', '연합뉴스', '한국경제'};

    final results = await RssService.fetchAllNews(
      stocks,
      allowedSources: allowedSources,
    );

    print('=== 현대차 (필터 있음) Result: ${results.length} ===');
    for (final item in results) {
      print('[${item.source}] ${item.publishedAt.toLocal()} | ${item.title}');
    }

    expect(results.length, greaterThan(0), reason: '24시간 이내 기사가 1건 이상이어야 함');
  });

  test('Naver News API test - 현대차 (언론사 필터 없음)', () async {
    final stocks = [
      Stock(name: '현대차', keywords: ['현대차']),
    ];

    final results = await RssService.fetchAllNews(stocks);

    print('=== 현대차 (필터 없음) Result: ${results.length} ===');
    for (final item in results.take(5)) {
      print('[${item.source}] ${item.publishedAt.toLocal()} | ${item.title}');
    }

    expect(results.length, greaterThan(0), reason: '24시간 이내 기사가 1건 이상이어야 함');
  });
}
