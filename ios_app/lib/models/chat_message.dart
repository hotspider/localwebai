enum ChatMessageSendState { sent, sending, failed }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.contentText,
    required this.model,
    required this.webSearchEnabled,
    required this.sources,
    required this.createdAt,
    this.sendState = ChatMessageSendState.sent,
    this.sendError,
  });

  final String id;
  final String role; // user | assistant
  final String contentText;
  final String model;
  final bool webSearchEnabled;
  final List<Map<String, dynamic>> sources;
  final DateTime createdAt;
  final ChatMessageSendState sendState;
  final String? sendError;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final rawSources = (j['sources'] as List?) ?? const <dynamic>[];
    return ChatMessage(
      id: (j['id'] ?? '').toString(),
      role: (j['role'] ?? 'assistant').toString(),
      contentText: j['content_text'] as String? ?? '',
      model: j['model'] as String? ?? 'chatgpt-5.2',
      webSearchEnabled: j['web_search_enabled'] as bool? ?? false,
      sources: rawSources
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      sendState: ChatMessageSendState.sent,
    );
  }
}

