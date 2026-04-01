class AttachmentItem {
  AttachmentItem({
    required this.id,
    required this.sessionId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final DateTime createdAt;

  factory AttachmentItem.fromJson(Map<String, dynamic> j) {
    final rawSize = j['size_bytes'];
    final size = rawSize is int ? rawSize : int.tryParse(rawSize?.toString() ?? '') ?? 0;
    return AttachmentItem(
      id: (j['id'] ?? '').toString(),
      sessionId: (j['session_id'] ?? '').toString(),
      filename: j['filename'] as String? ?? '',
      contentType: j['content_type'] as String? ?? '',
      sizeBytes: size,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

