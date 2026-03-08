import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';

void main() async {
  final queries = [
    '현대차 +(서울경제|매일경제|연합뉴스|한국경제)',
    '현대차 2026.03.08 +(서울경제|매일경제|연합뉴스|한국경제)',
    '현대차 오늘 +(서울경제|매일경제|연합뉴스|한국경제)',
  ];

  for (final q in queries) {
    final url = Uri.parse('https://openapi.naver.com/v1/search/news.json?query=${Uri.encodeComponent(q)}&display=5&sort=sim');
    final response = await http.get(url, headers: {
      'X-Naver-Client-Id': '1bYt64mfI_HwbOP4oqai',
      'X-Naver-Client-Secret': 'cJPqOkVZd6',
    });
    
    final items = jsonDecode(response.body)['items'] as List?;
    print('Query: $q -> count: ${items?.length ?? 0}');
  }
}
