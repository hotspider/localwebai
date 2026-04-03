import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/chat_colors.dart';

/// 全屏预览 PDF 附件
class AttachmentPdfPreviewScreen extends StatefulWidget {
  const AttachmentPdfPreviewScreen({
    required this.attachmentId,
    required this.title,
    super.key,
  });

  final String attachmentId;
  final String title;

  @override
  State<AttachmentPdfPreviewScreen> createState() => _AttachmentPdfPreviewScreenState();
}

class _AttachmentPdfPreviewScreenState extends State<AttachmentPdfPreviewScreen> {
  Future<Uint8List>? _loadFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFuture ??= context.read<ApiClient>().getBytes('/api/attachments/${widget.attachmentId}/file');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.pageBg,
      appBar: AppBar(
        backgroundColor: ChatColors.topBarBg,
        foregroundColor: ChatColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title.isEmpty ? 'PDF' : widget.title,
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
                  style: const TextStyle(color: ChatColors.textSecondary, fontSize: 15),
                ),
              ),
            );
          }
          final bytes = snap.data;
          if (bytes == null || bytes.isEmpty) {
            return const Center(child: Text('无数据'));
          }
          return _PdfPinchView(bytes: bytes);
        },
      ),
    );
  }
}

class _PdfPinchView extends StatefulWidget {
  const _PdfPinchView({required this.bytes});

  final Uint8List bytes;

  @override
  State<_PdfPinchView> createState() => _PdfPinchViewState();
}

class _PdfPinchViewState extends State<_PdfPinchView> {
  late final PdfControllerPinch _controller = PdfControllerPinch(
    document: PdfDocument.openData(widget.bytes),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(controller: _controller);
  }
}
