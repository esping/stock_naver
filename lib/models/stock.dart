class Stock {
  final String name;
  final List<String> keywords;

  Stock({
    required this.name,
    required this.keywords,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      name: json['name'] as String,
      keywords: List<String>.from(json['keywords'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'keywords': keywords,
      };

  Stock copyWith({String? name, List<String>? keywords}) {
    return Stock(
      name: name ?? this.name,
      keywords: keywords ?? this.keywords,
    );
  }
}
