/// Model representing a locally saved reply, caption, or card creation.
class HistoryItem {
  final String id;
  final String title;
  final String content;
  final String type; // 'reply', 'caption', 'card'
  final String category; // tone, platform, or template name
  final DateTime createdAt;
  final bool isFavorite;
  final String? extraData; // JSON or metadata string

  const HistoryItem({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.category,
    required this.createdAt,
    this.isFavorite = false,
    this.extraData,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type,
        'category': category,
        'created_at': createdAt.toIso8601String(),
        'is_favorite': isFavorite ? 1 : 0,
        'extra_data': extraData,
      };

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      type: map['type'] as String,
      category: (map['category'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      isFavorite: (map['is_favorite'] as int?) == 1,
      extraData: map['extra_data'] as String?,
    );
  }

  HistoryItem copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    String? category,
    DateTime? createdAt,
    bool? isFavorite,
    String? extraData,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      extraData: extraData ?? this.extraData,
    );
  }
}
