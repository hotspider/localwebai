import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/chat_colors.dart';

/// 全屏预览用户消息中的图片附件（需登录，走 /api/attachments/{id}/file）
class AttachmentImagePreviewScreen extends StatefulWidget {
  const AttachmentImagePreviewScreen({
    required this.attachmentId,
    required this.title,
    super.key,
  });

  final String attachmentId;
  final String title;

  @override
  State<AttachmentImagePreviewScreen> createState() => _AttachmentImagePreviewScreenState();
}

class _AttachmentImagePreviewScreenState extends State<AttachmentImagePreviewScreen> {
  Future<Uint8List>? _loadFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFuture ??= context.read<ApiClient>().getBytes('/api/attachments/${widget.attachmentId}/file');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title.isEmpty ? '图片' : widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<Uint8List>(
        future: _loadFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: ChatColors.accentBlue));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载失败：${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            );
          }
          final bytes = snap.data;
          if (bytes == null || bytes.isEmpty) {
            return const Center(child: Text('无数据', style: TextStyle(color: Colors.white70)));
          }
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
