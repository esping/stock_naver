import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final q = '현대차 +(서울경제|매일경제|연합뉴스|한국경제)';
  final url = Uri.parse('https://openapi.naver.com/v1/search/news.json?query=${Uri.encodeComponent(q)}&display=20&start=1&sort=date');
  
  final response = await http.get(url, headers: {
    'X-Naver-Client-Id': '1bYt64mfI_HwbOP4oqai',
    'X-Naver-Client-Secret': 'cJPqOkVZd6',
  });
  
  final items = jsonDecode(response.body)['items'] as List?;
  if (items != null) {
    for (final item in items) {
      final originallink = item['originallink'] ?? '';
      String source = '';
      if (originallink.isNotEmpty) {
        try {
          final uri = Uri.parse(originallink);
          source = uri.host.replaceFirst('www.', '');
        } catch (_) {}
      }
      print('Date: ${item['pubDate']}, Source: $source, Title: ${item['title']}');
    }
  }
}
