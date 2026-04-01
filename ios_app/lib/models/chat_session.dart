class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.defaultModel,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String defaultModel;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ChatSession.fromJson(Map<String, dynamic> j) {
    return ChatSession(
      id: (j['id'] ?? '').toString(),
      title: j['title'] as String? ?? '',
      defaultModel: j['default_model'] as String? ?? 'chatgpt-5.2',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  ChatSession copyWith({String? title, String? defaultModel, DateTime? updatedAt}) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      defaultModel: defaultModel ?? this.defaultModel,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

