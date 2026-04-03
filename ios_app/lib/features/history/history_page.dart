import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/chat_display_strings.dart';
import '../../core/format/session_time.dart';
import '../../core/theme/chat_colors.dart';
import '../../core/ui/app_dialogs.dart';
import '../../models/llm_model.dart';
import '../chat/chat_controller.dart';
import 'history_controller.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<HistoryController>().fetchSessionList(resetToRecent: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleListFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      context.read<HistoryController>().fetchSessionList(q: _search.text.trim());
    });
  }

  Future<void> _openSession(BuildContext context, String id) async {
    await context.read<ChatController>().openSession(id);
    if (!context.mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已打开该对话')));
    }
  }

  Future<void> _deleteSession(BuildContext context, String id) async {
    final ok = await showAppConfirmDialog(
      context,
      title: '删除这条对话？',
      message: '删除后将无法恢复，请确认是否继续。',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (ok == true && context.mounted) {
      final success = await context.read<HistoryController>().deleteSession(id);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (success) {
        messenger.showSnackBar(const SnackBar(content: Text('已删除该对话')));
      } else {
        final err = context.read<HistoryController>().error;
        if (err != null) {
          messenger.showSnackBar(SnackBar(content: Text(err)));
          context.read<HistoryController>().clearError();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryController>();
    final hasQuery = h.listSearchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: ChatColors.pageBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: ChatColors.topBarBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ChatColors.textPrimary,
        title: const Text('历史对话', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: ChatColors.dividerMain),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h.error != null && !h.loading)
            MaterialBanner(
              content: Text(h.error!, style: const TextStyle(fontSize: 14)),
              backgroundColor: ChatColors.errorBg,
              actions: [
                TextButton(
                  onPressed: () {
                    context.read<HistoryController>().clearError();
                  },
                  child: const Text('关闭'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<HistoryController>().clearError();
                    context.read<HistoryController>().fetchSessionList();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                setState(() {});
                _scheduleListFetch();
              },
              style: const TextStyle(color: ChatColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: '搜索对话标题或内容',
                hintStyle: TextStyle(color: ChatColors.textMuted.withValues(alpha: 0.9)),
                prefixIcon: const Icon(Icons.search_rounded, color: ChatColors.textTertiary),
                filled: true,
                fillColor: ChatColors.contentBg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: ChatColors.dividerMain),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: ChatColors.dividerMain),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: ChatColors.inputFocusBorder, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (h.loading && h.sessions.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: ChatColors.accentBlue));
                }
                if (h.sessions.isEmpty) {
                  if (hasQuery) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 44,
                              color: ChatColors.textMuted.withValues(alpha: 0.45),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              '未找到相关对话',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: ChatColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '试试更换关键词，或缩短检索词。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ChatColors.textMuted, fontSize: 14, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ChatColors.textSecondary,
                                side: const BorderSide(color: ChatColors.dividerMain),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () {
                                _debounce?.cancel();
                                _search.clear();
                                setState(() {});
                                context.read<HistoryController>().fetchSessionList(q: '');
                              },
                              child: const Text('清除搜索'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 44,
                            color: ChatColors.textMuted.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '还没有历史对话',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: ChatColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '发起一次新对话后，聊天记录会显示在这里。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ChatColors.textMuted, fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: ChatColors.accentBlue,
                              foregroundColor: ChatColors.textOnAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () async {
                              await context.read<ChatController>().newSession();
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                            child: const Text('去发起新对话'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: h.sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = h.sessions[i];
                    final title = s['title'] as String?;
                    final displayTitle = displayChatSessionTitle(title);
                    final modelLabel = LlmModel.fromApi(s['default_model'] as String? ?? 'chatgpt-5.2').label;
                    final timeStr = formatSessionListTime(s['last_message_at'] as String?);
                    final rawCount = s['attachment_count'];
                    final attachmentCount = rawCount is int
                        ? rawCount
                        : int.tryParse(rawCount?.toString() ?? '') ?? 0;
                    final secondLine = <String>[
                      if (timeStr.isNotEmpty) timeStr,
                      modelLabel,
                    ].join(' · ');
                    return Material(
                      color: ChatColors.contentBg,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openSession(context, s['id'] as String),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ChatColors.dividerMain),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                        height: 1.25,
                                        color: ChatColors.textPrimary,
                                      ),
                                    ),
                                    if (secondLine.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        secondLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.2,
                                          color: ChatColors.textMuted,
                                        ),
                                      ),
                                    ],
                                    if (attachmentCount > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '$attachmentCount 个附件',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.2,
                                          color: ChatColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                icon: Icon(Icons.more_vert_rounded, size: 20, color: ChatColors.textMuted.withValues(alpha: 0.85)),
                                onSelected: (v) {
                                  if (v == 'delete') {
                                    _deleteSession(context, s['id'] as String);
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(value: 'delete', child: Text('删除对话')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
