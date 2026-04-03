import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../core/api/api_client.dart';
import '../../core/format/error_messages.dart';
import '../../models/attachment.dart';
import '../../models/chat_message.dart';
import '../../models/chat_session.dart';
import '../../models/llm_model.dart';

class ChatController extends ChangeNotifier {
  ChatController({required this.apiClient});

  final ApiClient apiClient;

  ChatSession? currentSession;
  List<ChatMessage> messages = [];
  List<AttachmentItem> attachments = [];

  LlmModel model = LlmModel.chatgpt52;
  bool webSearchEnabled = false; // 默认关闭

  bool sessionLoading = false;
  bool sending = false;
  String? error;
  String? uploadError;

  bool canWebSearch = false;
  bool canUpload = true;

  /// 后端配置的路由模型 -> 实际提供商 model id（用于前端展示一致性）
  final Map<String, String> resolvedModelIdByRoute = {};

  /// `/api/models` 是否已成功拉取（失败时仅影响「后端实际模型」副标题，不影响发消息）
  bool routeModelsCatalogReady = false;

  // 本地附件草稿队列（更像 ChatGPT/DeepSeek：可显示上传中/失败可重试/可移除）
  // ignore: library_private_types_in_public_api
  final List<_AttachmentDraft> attachmentDrafts = [];

  bool get uploadingAny => attachmentDrafts.any((d) => d.status == _DraftStatus.uploading);

  /// 已上传、待发送的附件（用于像 DeepSeek 那样在输入框上方保持“本次将发送的图片/文件”标识）
  final List<String> pendingAttachmentIds = [];

  /// 待发送图片缩略图（上传成功后保留，用于像截图那样显示真实缩略图）
  final Map<String, Uint8List> _pendingPreviewBytes = {};

  Uint8List? pendingPreviewBytes(String attachmentId) => _pendingPreviewBytes[attachmentId];

  /// 本地记录：某条用户消息对应的附件（后端当前是“会话级附件”，这里用客户端映射实现“消息气泡上可见”）。
  final Map<String, List<AttachmentItem>> _messageAttachments = {};

  List<AttachmentItem> attachmentsForMessage(String messageId) => _messageAttachments[messageId] ?? const [];

  /// 根据消息上的 attachmentIds 与会话 attachments 列表重建气泡映射（并重挂 local_ 乐观消息）
  void _syncMessageAttachmentsFromMessages() {
    final merged = <String, List<AttachmentItem>>{};
    for (final m in messages) {
      if (m.role != 'user' || m.attachmentIds.isEmpty) continue;
      final items = m.attachmentIds
          .map((id) => attachments.where((a) => a.id == id).toList().firstOrNull)
          .whereType<AttachmentItem>()
          .toList();
      if (items.isNotEmpty) merged[m.id] = items;
    }
    for (final e in _messageAttachments.entries) {
      if (e.key.startsWith('local_')) merged[e.key] = e.value;
    }
    _messageAttachments
      ..clear()
      ..addAll(merged);
  }

  /// 用户气泡内是否仍显示「发送中…」（与列表底部「正在生成回复」互斥）
  bool outboundSendingRowVisible(String messageId) => !(_chatRequestBodyDispatched[messageId] ?? false);

  /// 列表底部生成占位：仅在请求体已发出、等待服务端/模型时显示
  bool get showAssistantGeneratingTail {
    if (!sending) return false;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.role == 'user' && m.sendState == ChatMessageSendState.sending) {
        return _chatRequestBodyDispatched[m.id] == true;
      }
    }
    return false;
  }

  void _markChatRequestBodyDispatched(String localMessageId) {
    if (_chatRequestBodyDispatched[localMessageId] == true) return;
    _chatRequestBodyDispatched[localMessageId] = true;
    notifyListeners();
  }

  final Map<String, _PendingSend> _pendingSends = {};
  int _inflightSends = 0;

  /// 聊天 POST 请求体已写入连接（视为「发送成功」）；此后才展示「正在生成回复」
  final Map<String, bool> _chatRequestBodyDispatched = {};

  Future<void> syncMePermissions() async {
    try {
      final me = await apiClient.getJson('/api/me');
      canWebSearch = me['can_web_search'] as bool? ?? false;
      canUpload = me['can_upload'] as bool? ?? true;
      try {
        final models = await apiClient.getJson('/api/models');
        final items = (models['items'] as List?)?.cast<Map>() ?? const <Map>[];
        resolvedModelIdByRoute
          ..clear()
          ..addEntries(
            items
                .map((e) => e.cast<String, dynamic>())
                .where((e) => (e['route']?.toString().isNotEmpty ?? false))
                .map(
                  (e) => MapEntry(
                    e['route'].toString(),
                    (e['resolved_model'] ?? e['resolved_openai_model'] ?? '').toString(),
                  ),
                ),
          );
        routeModelsCatalogReady = true;
      } catch (e, st) {
        routeModelsCatalogReady = false;
        debugPrint('GET /api/models 失败（仅影响模型映射展示）: $e\n$st');
      }
    } on ApiException catch (e) {
      if (e.code == 'UNAUTHORIZED') {
        canWebSearch = false;
        canUpload = true;
      } else if (e.code == 'NETWORK_ERROR') {
        // 权限拉取失败不应导致页面崩溃；先用保守默认值，后续可自动重试刷新。
        canWebSearch = false;
        canUpload = true;
      } else {
        rethrow;
      }
    }
    notifyListeners();
  }

  void setModel(LlmModel m) {
    model = m;
    notifyListeners();
  }

  void setWebSearchEnabled(bool v) {
    webSearchEnabled = v;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void clearUploadError() {
    uploadError = null;
    notifyListeners();
  }

  /// 开始一个“本地新对话”（不落库）；仅在发送/上传时再创建 session。
  Future<void> newSession() async {
    sessionLoading = false;
    error = null;
    uploadError = null;
    attachmentDrafts.clear();
    pendingAttachmentIds.clear();
    _pendingPreviewBytes.clear();
    _messageAttachments.clear();
    currentSession = null;
    messages = [];
    attachments = [];
    webSearchEnabled = false;
    notifyListeners();
  }

  Future<bool> _ensureSessionCreated({bool showLoading = true}) async {
    if (currentSession != null) return true;
    if (showLoading) {
      sessionLoading = true;
      error = null;
      notifyListeners();
    }
    try {
      final resp = await apiClient.postJson(
        '/api/sessions',
        {'title': '', 'default_model': model.apiValue},
        receiveTimeout: const Duration(seconds: 30),
      );
      currentSession = ChatSession.fromJson((resp['session'] as Map).cast<String, dynamic>());
      // 关键：在“乐观发送/上传”等不展示全屏 loading 的链路里，不能立刻 refreshSession()，
      // 否则会把本地 optimistic 消息覆盖掉，出现“消息一闪而过”的现象。
      if (showLoading) {
        await refreshSession();
      }
      return true;
    } catch (e) {
      error = describeErrorForUser(e);
      return false;
    } finally {
      if (showLoading) {
        sessionLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> openSession(String sessionId) async {
    sessionLoading = true;
    error = null;
    uploadError = null;
    attachmentDrafts.clear();
    pendingAttachmentIds.clear();
    _pendingPreviewBytes.clear();
    _messageAttachments.clear();
    notifyListeners();
    try {
      final resp = await apiClient.getJson('/api/sessions/$sessionId');
      currentSession = ChatSession.fromJson((resp['session'] as Map).cast<String, dynamic>());
      messages = ((resp['messages'] as List?) ?? const <dynamic>[])
          .cast<Map>()
          .map((e) => ChatMessage.fromJson(e.cast<String, dynamic>()))
          .toList();
      attachments = ((resp['attachments'] as List?) ?? const <dynamic>[])
          .cast<Map>()
          .map((e) => AttachmentItem.fromJson(e.cast<String, dynamic>()))
          .toList();
      _syncMessageAttachmentsFromMessages();
      model = LlmModel.fromApi(currentSession!.defaultModel);
      webSearchEnabled = false;
    } catch (e) {
      error = describeErrorForUser(e);
    } finally {
      sessionLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSession() async {
    final s = currentSession;
    if (s == null) return;
    try {
      final resp = await apiClient.getJson('/api/sessions/${s.id}');
      final serverMessages = ((resp['messages'] as List?) ?? const <dynamic>[])
          .cast<Map>()
          .map((e) => ChatMessage.fromJson(e.cast<String, dynamic>()))
          .toList();
      // 保留本地 optimistic 消息，避免被服务端“尚未写入/尚未返回”的列表覆盖。
      final localPending = messages
          .where((m) => m.id.startsWith('local_') && m.sendState != ChatMessageSendState.sent)
          .toList();
      messages = [...serverMessages, ...localPending];
      attachments = ((resp['attachments'] as List?) ?? const <dynamic>[])
          .cast<Map>()
          .map((e) => AttachmentItem.fromJson(e.cast<String, dynamic>()))
          .toList();
      _syncMessageAttachmentsFromMessages();
      // 刷新成功后不应残留上传错误提示
      uploadError = null;
    } catch (e) {
      // refreshSession 失败不应污染“发送失败”的 error banner
      uploadError = describeErrorForUser(e);
      if (kDebugMode) {
        debugPrint('refreshSession failed: $e');
      }
    } finally {
      notifyListeners();
    }
  }

  /// 返回值：是否已“入队”（即已创建会话并把用户消息放入列表）。
  /// - true：UI 至少会立刻看到用户消息（后续模型失败也会保留该消息并提示错误）
  /// - false：会话创建失败/其他前置失败；调用方可选择不清空输入框
  Future<bool> sendText(String text) async {
    // 兼容旧调用：改为乐观入队 + 异步发送
    return enqueueSend(text);
  }

  /// 发送：立即插入用户气泡并清空“输入区附件预览”，后台异步发送。
  /// 返回值：是否已插入本地用户消息（用于调用方立即清空输入框）。
  bool enqueueSend(String text) {
    final trimmed = text.trim();
    final idsForSend = List<String>.from(pendingAttachmentIds);
    final pendingItems = pendingAttachmentIds
        .map((id) => attachments.where((a) => a.id == id).toList().firstOrNull)
        .whereType<AttachmentItem>()
        .toList();

    final effectiveWeb = canWebSearch && webSearchEnabled;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}_${_randId()}';

    final optimisticUser = ChatMessage(
      id: localId,
      role: 'user',
      contentText: trimmed,
      model: model.apiValue,
      webSearchEnabled: effectiveWeb,
      sources: const [],
      createdAt: DateTime.now(),
      sendState: ChatMessageSendState.sending,
      attachmentIds: pendingItems.map((e) => e.id).toList(),
    );
    messages = [...messages, optimisticUser];
    if (pendingItems.isNotEmpty) {
      _messageAttachments[localId] = pendingItems;
    }

    // 发送瞬间：输入区附件预览移除（文本由调用方清空 controller）
    pendingAttachmentIds.clear();
    _pendingPreviewBytes.clear();
    uploadError = null;

    _pendingSends[localId] = _PendingSend(
      localMessageId: localId,
      text: trimmed,
      modelApiValue: model.apiValue,
      webSearchEnabled: effectiveWeb,
      attachmentIds: idsForSend,
    );

    notifyListeners();

    // ignore: discarded_futures
    _performSend(localId);
    return true;
  }

  Future<void> retrySend(String localMessageId) async {
    if (!_pendingSends.containsKey(localMessageId)) return;
    final idx = messages.indexWhere((m) => m.id == localMessageId);
    if (idx >= 0) {
      final m = messages[idx];
      messages = [
        ...messages.sublist(0, idx),
        ChatMessage(
          id: m.id,
          role: m.role,
          contentText: m.contentText,
          model: m.model,
          webSearchEnabled: m.webSearchEnabled,
          sources: m.sources,
          createdAt: m.createdAt,
          sendState: ChatMessageSendState.sending,
          realtimeMeta: m.realtimeMeta,
          attachmentIds: m.attachmentIds,
        ),
        ...messages.sublist(idx + 1),
      ];
      notifyListeners();
    }
    await _performSend(localMessageId);
  }

  Future<void> _performSend(String localMessageId) async {
    final payload = _pendingSends[localMessageId];
    if (payload == null) return;

    _inflightSends += 1;
    sending = _inflightSends > 0;
    error = null;
    notifyListeners();

    final ok = await _ensureSessionCreated(showLoading: false);
    if (!ok || currentSession == null) {
      _markSendFailed(localMessageId, '无法创建会话，请检查网络与登录状态');
      _inflightSends = max(0, _inflightSends - 1);
      sending = _inflightSends > 0;
      notifyListeners();
      return;
    }
    final sessionId = currentSession!.id;

    _chatRequestBodyDispatched[localMessageId] = false;

    Timer? outboundFallback;
    outboundFallback = Timer(const Duration(milliseconds: 600), () {
      _markChatRequestBodyDispatched(localMessageId);
    });

    try {
      final resp = await apiClient.postJson(
        '/api/chat/messages',
        {
        'session_id': sessionId,
        'model': payload.modelApiValue,
        'web_search_enabled': payload.webSearchEnabled,
        'text': payload.text,
        'attachment_ids': payload.attachmentIds,
        },
        // 模型端响应可能 > 60s；避免前端 receiveTimeout 误判“网络异常”
        receiveTimeout: const Duration(minutes: 5),
        onSendProgress: (sent, total) {
          if (total <= 0) {
            if (sent > 0) _markChatRequestBodyDispatched(localMessageId);
          } else if (sent >= total) {
            _markChatRequestBodyDispatched(localMessageId);
          }
        },
      );
      final um = ChatMessage.fromJson((resp['user_message'] as Map).cast<String, dynamic>());
      final am = ChatMessage.fromJson((resp['assistant_message'] as Map).cast<String, dynamic>());

      final idx = messages.indexWhere((m) => m.id == localMessageId);
      if (idx >= 0) {
        final next = [...messages];
        next[idx] = um;
        next.insert(idx + 1, am);
        messages = next;
      } else {
        messages = [...messages, um, am];
      }

      final atts = _messageAttachments.remove(localMessageId);
      if (atts != null && atts.isNotEmpty) {
        _messageAttachments[um.id] = atts;
      }

      _pendingSends.remove(localMessageId);

      final newTitle = resp['session_title'] as String?;
      if (newTitle != null && newTitle.trim().isNotEmpty && currentSession != null) {
        currentSession = currentSession!.copyWith(title: newTitle.trim());
      }
    } catch (e) {
      _markSendFailed(localMessageId, describeErrorForUser(e));
    } finally {
      outboundFallback.cancel();
      _chatRequestBodyDispatched.remove(localMessageId);
      _inflightSends = max(0, _inflightSends - 1);
      sending = _inflightSends > 0;
      notifyListeners();
    }
  }

  void _markSendFailed(String localMessageId, String message) {
    final idx = messages.indexWhere((m) => m.id == localMessageId);
    if (idx < 0) {
      error = message;
      return;
    }
    final m = messages[idx];
    messages = [
      ...messages.sublist(0, idx),
      ChatMessage(
        id: m.id,
        role: m.role,
        contentText: m.contentText,
        model: m.model,
        webSearchEnabled: m.webSearchEnabled,
        sources: m.sources,
        createdAt: m.createdAt,
        sendState: ChatMessageSendState.failed,
        sendError: message,
        realtimeMeta: m.realtimeMeta,
        attachmentIds: m.attachmentIds,
      ),
      ...messages.sublist(idx + 1),
    ];
  }

  static const _maxAttachmentBytes = 10 * 1024 * 1024;
  final ImagePicker _imagePicker = ImagePicker();

  /// 拍照上传（模拟器无相机时可能失败，请用真机或相册）
  Future<void> uploadFromCamera() async {
    if (!await _ensureCanUpload()) return;
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 90,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final meta = _resolvePickedImageMeta(x, bytes);
      await _enqueueAndUpload(bytes, meta.filename, meta.contentType);
    } catch (e) {
      uploadError = describeErrorForUser(e);
      notifyListeners();
    }
  }

  /// 从相册选择图片
  Future<void> uploadFromGallery() async {
    if (!await _ensureCanUpload()) return;
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 90,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final meta = _resolvePickedImageMeta(x, bytes);
      await _enqueueAndUpload(bytes, meta.filename, meta.contentType);
    } catch (e) {
      uploadError = describeErrorForUser(e);
      notifyListeners();
    }
  }

  /// 选择文件（PDF、Word、文本等）
  Future<void> pickFileAndUpload() async {
    if (!await _ensureCanUpload()) return;

    const group = XTypeGroup(
      label: 'attachments',
      extensions: ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'webp'],
      uniformTypeIdentifiers: [
        'com.adobe.pdf',
        'org.openxmlformats.wordprocessingml.document',
        'public.plain-text',
        'public.jpeg',
        'public.png',
        'public.webp',
      ],
    );
    final xfile = await openFile(acceptedTypeGroups: [group]);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    await _enqueueAndUpload(bytes, xfile.name, _guessContentType(xfile.name));
  }

  Future<bool> _ensureCanUpload() async {
    if (!canUpload) {
      error = '当前账号不允许上传附件';
      notifyListeners();
      return false;
    }
    final ok = await _ensureSessionCreated(showLoading: false);
    if (!ok || currentSession == null) {
      error = '无法创建会话，请检查网络与登录状态';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> _enqueueAndUpload(List<int> bytes, String filename, String contentType) async {
    final draft = _AttachmentDraft(
      localId: _randId(),
      filename: filename,
      contentType: contentType,
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      status: _DraftStatus.queued,
    );
    attachmentDrafts.insert(0, draft);
    uploadError = null;
    notifyListeners();
    await _uploadDraft(draft);
  }

  Future<void> retryUploadDraft(String localId) async {
    final d = attachmentDrafts.where((x) => x.localId == localId).toList().firstOrNull;
    if (d == null) return;
    await _uploadDraft(d);
  }

  void removeDraft(String localId) {
    attachmentDrafts.removeWhere((d) => d.localId == localId);
    notifyListeners();
  }

  Future<void> _uploadDraft(_AttachmentDraft draft) async {
    final sessionId = currentSession!.id;

    if (draft.bytes.length > _maxAttachmentBytes) {
      draft.status = _DraftStatus.failed;
      draft.error = '文件超过 10MB';
      uploadError = draft.error;
      notifyListeners();
      return;
    }

    draft.status = _DraftStatus.uploading;
    draft.error = null;
    uploadError = null;
    notifyListeners();
    try {
      final presign = await apiClient.postJson('/api/attachments/presign', {
        'session_id': sessionId,
        'filename': draft.filename,
        'content_type': draft.contentType,
        'size_bytes': draft.bytes.length,
      });
      final attachmentId = (presign['attachment_id'] ?? '').toString();
      final upload = (presign['upload'] as Map).cast<String, dynamic>();
      final uploadUrl = upload['url'] as String;
      final body = draft.bytes;
      final uploadHeaders = <String, dynamic>{
        ...(upload['headers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      };
      // 关键：必须覆盖 BaseOptions 里的 application/json，且避免大小写重复导致签名不匹配
      uploadHeaders.remove('Content-Type');
      uploadHeaders.remove(HttpHeaders.contentTypeHeader);
      uploadHeaders[HttpHeaders.contentTypeHeader] = draft.contentType;
      // 不要手动设置 Content-Length：dio 可能同时使用 chunked 传输或重复设置，
      // Nginx 会直接判定为 Bad Request（400）。

      final uploadOptions = Options(
        headers: uploadHeaders,
        extra: const {'skipAuth': true},
        responseType: ResponseType.plain,
      );

      if (uploadUrl.startsWith('http://') || uploadUrl.startsWith('https://')) {
        await apiClient.dio.put(
          uploadUrl,
          data: body,
          options: uploadOptions,
        );
      } else {
        final base = Uri.parse(apiClient.dio.options.baseUrl);
        final uri = base.resolve(uploadUrl);
        await apiClient.dio.putUri(
          uri,
          data: body,
          options: uploadOptions,
        );
      }

      await apiClient.postJson('/api/attachments/commit', {'attachment_id': presign['attachment_id']});

      await refreshSession();
      // 成功：移除草稿
      attachmentDrafts.removeWhere((d) => d.localId == draft.localId);
      if (attachmentId.isNotEmpty && !pendingAttachmentIds.contains(attachmentId)) {
        pendingAttachmentIds.insert(0, attachmentId);
        if (draft.isImage) {
          _pendingPreviewBytes[attachmentId] = draft.bytes;
        }
      }
      uploadError = null;
    } catch (e, st) {
      if (kDebugMode) {
        // 便于定位：预签名上传失败通常会返回 403/XML/纯文本
        debugPrint('upload failed: $e');
        debugPrintStack(stackTrace: st);
        if (e is DioException) {
          debugPrint('upload dio status: ${e.response?.statusCode}');
          debugPrint('upload dio data: ${e.response?.data}');
        }
      }
      draft.status = _DraftStatus.failed;
      draft.error = describeErrorForUser(e);
      uploadError = draft.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteAttachment(String attachmentId) async {
    // 删除附件不应影响发送状态；并将错误归类为上传相关
    uploadError = null;
    notifyListeners();
    try {
      await apiClient.delete('/api/attachments/$attachmentId');
      pendingAttachmentIds.removeWhere((id) => id == attachmentId);
      _pendingPreviewBytes.remove(attachmentId);
      await refreshSession();
    } catch (e) {
      uploadError = describeErrorForUser(e);
    } finally {
      notifyListeners();
    }
  }

  String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  /// iOS 相册常为 .HEIC 文件名，但实际字节已是 JPEG；按魔数 + mime 对齐后端允许的三种图片类型。
  ({String filename, String contentType}) _resolvePickedImageMeta(XFile x, List<int> raw) {
    final b = raw is Uint8List ? raw : Uint8List.fromList(raw);
    var name = x.name.trim().isNotEmpty ? x.name.trim() : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8) {
      return (filename: _withImageExtension(name, '.jpg'), contentType: 'image/jpeg');
    }
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return (filename: _withImageExtension(name, '.png'), contentType: 'image/png');
    }
    if (b.length >= 12) {
      final head = String.fromCharCodes(b.sublist(0, 4));
      final webp = String.fromCharCodes(b.sublist(8, 12));
      if (head == 'RIFF' && webp == 'WEBP') {
        return (filename: _withImageExtension(name, '.webp'), contentType: 'image/webp');
      }
    }

    final mime = x.mimeType?.toLowerCase();
    if (mime == 'image/jpeg' || mime == 'image/jpg') {
      return (filename: _withImageExtension(name, '.jpg'), contentType: 'image/jpeg');
    }
    if (mime == 'image/png') {
      return (filename: _withImageExtension(name, '.png'), contentType: 'image/png');
    }
    if (mime == 'image/webp') {
      return (filename: _withImageExtension(name, '.webp'), contentType: 'image/webp');
    }

    final g = _guessContentType(name);
    if (g != 'application/octet-stream') {
      return (filename: name, contentType: g);
    }

    throw UnsupportedError(
      '无法识别图片格式（相册里若为 HEIC 原图，请在「照片」中导出为 JPG 再选，或更新 App 后重试）',
    );
  }

  String _withImageExtension(String filename, String extWithDot) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(extWithDot)) return filename;
    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    return '$base$extWithDot';
  }
}

enum _DraftStatus { queued, uploading, failed }

class _AttachmentDraft {
  _AttachmentDraft({
    required this.localId,
    required this.filename,
    required this.contentType,
    required this.bytes,
    required this.status,
  });

  final String localId;
  final String filename;
  final String contentType;
  final Uint8List bytes;
  _DraftStatus status;
  String? error;

  bool get isImage => contentType.toLowerCase().startsWith('image/');
}

String _randId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _PendingSend {
  _PendingSend({
    required this.localMessageId,
    required this.text,
    required this.modelApiValue,
    required this.webSearchEnabled,
    required this.attachmentIds,
  });

  final String localMessageId;
  final String text;
  final String modelApiValue;
  final bool webSearchEnabled;
  final List<String> attachmentIds;
}

