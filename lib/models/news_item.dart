class NewsItem {
  final String title;
  final String link;
  final String source;
  final String category;
  final DateTime publishedAt;
  final String stockName;

  NewsItem({
    required this.title,
    required this.link,
    required this.source,
    this.category = '',
    required this.publishedAt,
    required this.stockName,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] as String,
      link: json['link'] as String,
      source: json['source'] as String,
      category: (json['category'] as String?) ?? '',
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      stockName: json['stockName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'source': source,
        'category': category,
        'publishedAt': publishedAt.toIso8601String(),
        'stockName': stockName,
      };
}
