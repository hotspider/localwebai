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
    this.realtimeMeta,
    this.attachmentIds = const [],
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

  /// Brave 实时元数据：status / message / queried_at / provider 等
  final Map<String, dynamic>? realtimeMeta;

  /// 本条用户消息关联的附件 id（服务端持久化，用于重进会话后还原气泡）
  final List<String> attachmentIds;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final rawSources = (j['sources'] as List?) ?? const <dynamic>[];
    final rm = j['realtime_meta'];
    final rawAtt = j['attachment_ids'] as List?;
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
      realtimeMeta: rm is Map ? rm.cast<String, dynamic>() : null,
      attachmentIds: rawAtt == null ? [] : rawAtt.map((e) => e.toString()).toList(),
    );
  }
}

