import 'package:flutter_test/flutter_test.dart';
import 'package:stock_naver/models/stock.dart';
import 'package:stock_naver/services/rss_service.dart';

void main() {
  test('Naver News API test - 현대차', () async {
    final stocks = [
      Stock(name: '현대차', keywords: ['현대차']),
    ];
    const allowedSources = {'서울경제', '매일경제', '연합뉴스', '한국경제'}; 

    final results = await RssService.fetchAllNews(
      stocks,
      allowedSources: allowedSources,
    );

    print('=== 현대차 News Result: ${results.length} ===');
    for (final item in results) {
      print('[${item.source}] ${item.publishedAt.toLocal()} | ${item.title}');
    }

    expect(results, isA<List>());
  });
}
