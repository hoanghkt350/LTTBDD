class Article {
  final String id;
  final String title;
  final String category;
  final String author;
  final String publishedAt;
  final String thumbnailUrl;
  final String summary;
  final String content;
  final int readTimeMinutes;

  Article({
    required this.id,
    required this.title,
    required this.category,
    required this.author,
    required this.publishedAt,
    required this.thumbnailUrl,
    required this.summary,
    required this.content,
    this.readTimeMinutes = 5,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      author: json['author'] as String,
      publishedAt: json['publishedAt'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      summary: json['summary'] as String,
      content: (json['content'] as String?) ?? json['summary'] as String,
      readTimeMinutes: (json['readTimeMinutes'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'author': author,
      'publishedAt': publishedAt,
      'thumbnailUrl': thumbnailUrl,
      'summary': summary,
      'content': content,
      'readTimeMinutes': readTimeMinutes,
    };
  }
}
