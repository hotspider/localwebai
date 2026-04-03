import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/chat_colors.dart';
import '../../core/ui/model_selector_sheet.dart';
import '../history/history_controller.dart';
import '../settings/settings_page.dart';
import '../shell/chat_drawer.dart';
import '../../core/format/chat_display_strings.dart';
import '../../models/attachment.dart';
import 'attachment_preview/attachment_image_preview_screen.dart';
import 'attachment_preview/attachment_pdf_preview_screen.dart';
import 'chat_controller.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/chat_toast.dart';
import 'widgets/chat_top_bar.dart';
import 'widgets/empty_chat_state.dart';

String _sessionDisplayTitle(ChatController c) {
  return displayChatSessionTitle(c.currentSession?.title);
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _input = TextEditingController();
  final _listController = ScrollController();
  ChatController? _chat;
  int _lastMessageCount = 0;
  double _lastKeyboardInset = 0;

  void _onChatChanged() {
    final chat = _chat;
    if (chat == null) return;
    if (chat.messages.length != _lastMessageCount) {
      _lastMessageCount = chat.messages.length;
      _scrollToBottom();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final chat = context.read<ChatController>();
      _chat = chat;
      chat.addListener(_onChatChanged);
      await chat.syncMePermissions();
      if (!mounted) return;
      await chat.newSession();
      if (!mounted) return;
      _lastMessageCount = chat.messages.length;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat?.removeListener(_onChatChanged);
    _input.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      if (bottom > _lastKeyboardInset && bottom > 0) {
        _scrollToBottom();
      }
      _lastKeyboardInset = bottom;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) return;
      final max = _listController.position.maxScrollExtent;
      _listController.animateTo(max, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _openAttachmentPreview(AttachmentItem item) {
    final ct = item.contentType.toLowerCase();
    if (ct.startsWith('image/')) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentImagePreviewScreen(attachmentId: item.id, title: item.filename),
        ),
      );
      return;
    }
    if (ct == 'application/pdf') {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentPdfPreviewScreen(attachmentId: item.id, title: item.filename),
        ),
      );
      return;
    }
    showChatToast(context, '暂不支持预览该类型（当前支持图片与 PDF）');
  }

  Future<void> _send() async {
    final chat = context.read<ChatController>();
    final text = _input.text.trim();
    final hasPending = chat.pendingAttachmentIds.isNotEmpty || chat.attachmentDrafts.isNotEmpty;
    if (text.isEmpty && !hasPending) return;
    final accepted = chat.enqueueSend(text);
    if (accepted) _input.clear();
    if (!mounted) return;
    _scrollToBottom();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _openModelSheet(ChatController c) async {
    if (c.sessionLoading || c.sending) return;
    await showModelSelectorSheet(
      context,
      selected: c.model,
      appearance: ModelSelectorAppearance.chatProduct,
      resolvedModelIdByRoute: c.resolvedModelIdByRoute,
      onSelected: (m) {
        context.read<ChatController>().setModel(m);
        showChatToast(context, '已切换为 ${m.label}，后续回复将使用该模型');
      },
      onOpenSettings: () {
        Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
      },
    );
  }

  Future<void> _copyMessage(int index) async {
    final chat = context.read<ChatController>();
    final text = chat.messages[index].contentText;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showChatToast(context, '已复制到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChatController>();
    final hasMessages = c.messages.isNotEmpty;
    final initialLoading = c.sessionLoading && c.messages.isEmpty;
    final showComposer = !initialLoading;
    final showCenterComposer = showComposer && !hasMessages;
    final showBottomComposer = showComposer && hasMessages;

    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ChatColors.pageBg,
      // 手动用 viewInsets 整体上移，避免部分 iOS 输入法下 Scaffold 未压缩 body 导致键盘挡住消息区
      resizeToAvoidBottomInset: false,
      drawer: const ChatDrawer(),
      onDrawerChanged: (isOpen) {
        if (isOpen) {
          // 打开侧栏：清空搜索并拉取最近会话（与服务器同步标题/时间）
          // ignore: discarded_futures
          context.read<HistoryController>().fetchSessionList(resetToRecent: true);
        }
      },
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardBottom),
          child: Column(
            children: [
              ChatTopBar(
              modelLabel: c.model.label,
              sessionTitle: _sessionDisplayTitle(c),
              showSessionTitle: hasMessages,
              onOpenDrawer: _openDrawer,
              onOpenModelSheet: () => _openModelSheet(c),
              onNewSession: () {
                if (!c.sessionLoading && !c.sending) context.read<ChatController>().newSession();
              },
            ),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ChatColors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.panelInset),
                  border: Border.all(color: ChatColors.error.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: ChatColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.error!,
                        style: const TextStyle(color: ChatColors.error, fontSize: 13, height: 1.4),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.close_rounded, size: 20, color: ChatColors.textTertiary),
                      onPressed: () => context.read<ChatController>().clearError(),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: initialLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: ChatColors.accentBlue),
                        ),
                        SizedBox(height: 16),
                        Text('正在为你创建新对话…', style: TextStyle(color: ChatColors.textMuted, fontSize: 14)),
                      ],
                    ),
                  )
                : hasMessages
                    ? ChatMessageList(
                        scrollController: _listController,
                        messages: c.messages,
                        loading: c.showAssistantGeneratingTail,
                        onCopy: _copyMessage,
                        attachmentsForMessage: c.attachmentsForMessage,
                        onRetrySend: (id) => context.read<ChatController>().retrySend(id),
                        outboundSendingRowFor: c.outboundSendingRowVisible,
                        onOpenAttachment: _openAttachmentPreview,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Flexible(child: EmptyChatState(fillHeight: false)),
                                if (showCenterComposer) ...[
                                  const SizedBox(height: 16),
                                  ChatComposer(
                                    controller: _input,
                                    onSend: _send,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
          if (showBottomComposer)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.transparent),
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ChatComposer(
                    controller: _input,
                    onSend: _send,
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
