import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://openapi.naver.com/v1/search/news.json?query=%ED%98%84%EB%8C%80%EC%B0%A8&display=5&sort=date');
  final response = await http.get(url, headers: {
    'X-Naver-Client-Id': '1bYt64mfI_HwbOP4oqai',
    'X-Naver-Client-Secret': 'cJPqOkVZd6',
  });
  
  final items = jsonDecode(response.body)['items'] as List?;
  if (items != null && items.isNotEmpty) {
    print('Raw pubDate: ${items[0]['pubDate']}');
  }
}
