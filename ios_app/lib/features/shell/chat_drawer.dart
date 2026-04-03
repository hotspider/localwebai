import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/chat_display_strings.dart';
import '../../core/theme/chat_colors.dart';
import '../../core/ui/app_dialogs.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import '../history/history_controller.dart';
import '../history/history_page.dart';
import '../settings/settings_page.dart';

class ChatDrawer extends StatefulWidget {
  const ChatDrawer({super.key});

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  HistoryController? _hist;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchTextTick);
  }

  void _onSearchTextTick() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final h = context.read<HistoryController>();
    if (_hist != h) {
      _hist?.removeListener(_syncSearchFromHist);
      _hist = h;
      _hist!.addListener(_syncSearchFromHist);
    }
  }

  /// 父级 resetToRecent 清空关键词后，同步清空输入框（避免抢焦点时误清）
  void _syncSearchFromHist() {
    final h = _hist;
    if (h == null || !mounted) return;
    if (h.listSearchQuery.isEmpty && _search.text.isNotEmpty && !_searchFocus.hasFocus) {
      _search.removeListener(_onSearchTextTick);
      _search.clear();
      _search.addListener(_onSearchTextTick);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hist?.removeListener(_syncSearchFromHist);
    _search.removeListener(_onSearchTextTick);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      context.read<HistoryController>().fetchSessionList(q: _search.text.trim());
    });
  }

  Future<void> _confirmDelete(BuildContext context, String sessionId) async {
    final ok = await showAppConfirmDialog(
      context,
      title: '删除这条对话？',
      message: '删除后将无法恢复，请确认是否继续。',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (ok == true && context.mounted) {
      final success = await context.read<HistoryController>().deleteSession(sessionId);
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
    final auth = context.watch<AuthController>();
    final hist = context.watch<HistoryController>();
    final searchBusy = hist.loading && hist.listSearchQuery.trim().isNotEmpty;
    final username = auth.me?['username']?.toString() ?? '';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Drawer(
      backgroundColor: ChatColors.contentBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '家庭 AI 助手',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: ChatColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '最近会话与快捷入口',
                          style: TextStyle(fontSize: 12, color: ChatColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 22, color: ChatColors.textTertiary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ChatColors.accentBlue,
                      foregroundColor: ChatColors.textOnAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await context.read<ChatController>().newSession();
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('发起新对话', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ChatColors.textSecondary,
                      side: const BorderSide(color: ChatColors.dividerMain),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await context.read<HistoryController>().fetchSessionList(resetToRecent: true);
                      if (!context.mounted) return;
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
                      );
                    },
                    icon: const Icon(Icons.history_rounded, size: 20),
                    label: const Text('查看全部历史记录'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (_) => _scheduleSearch(),
                style: const TextStyle(color: ChatColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '搜索历史对话（标题或内容）',
                  hintStyle: TextStyle(color: ChatColors.textMuted.withValues(alpha: 0.9), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: ChatColors.textTertiary, size: 22),
                  suffixIcon: searchBusy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ChatColors.accentBlue),
                          ),
                        )
                      : _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: () {
                                _debounce?.cancel();
                                _search.clear();
                                context.read<HistoryController>().fetchSessionList(q: '');
                              },
                              icon: const Icon(Icons.close_rounded, color: ChatColors.textTertiary, size: 20),
                            ),
                  filled: true,
                  fillColor: ChatColors.pageBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: ChatColors.dividerMain),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: ChatColors.dividerMain),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: ChatColors.inputFocusBorder, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                hist.listSearchQuery.trim().isEmpty ? '最近对话' : '搜索结果',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ChatColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: hist.loading && hist.sessions.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: ChatColors.accentBlue))
                  : hist.sessions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: hist.listSearchQuery.trim().isNotEmpty
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 40, color: ChatColors.textMuted.withValues(alpha: 0.45)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        '未找到相关对话',
                                        style: TextStyle(color: ChatColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 16),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '可缩短或更换关键词；完整列表请点「查看全部历史记录」。',
                                        style: TextStyle(fontSize: 13, color: ChatColors.textMuted, height: 1.4),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_bubble_outline_rounded, size: 40, color: ChatColors.textMuted.withValues(alpha: 0.45)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        '还没有历史对话',
                                        style: TextStyle(color: ChatColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 16),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '发起一次新对话后，聊天记录会显示在这里。',
                                        style: TextStyle(fontSize: 13, color: ChatColors.textMuted, height: 1.4),
                                        textAlign: TextAlign.center,
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
                                          Navigator.pop(context);
                                          await context.read<ChatController>().newSession();
                                        },
                                        child: const Text('去发起新对话'),
                                      ),
                                    ],
                                  ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          itemCount: hist.sessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 0),
                          itemBuilder: (context, i) {
                            final s = hist.sessions[i];
                            final title = s['title'] as String?;
                            final label = displayChatSessionTitle(title);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await context.read<ChatController>().openSession(s['id'] as String);
                                },
                                child: SizedBox(
                                  height: 44,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                              height: 1.15,
                                              color: ChatColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: Icon(Icons.more_vert_rounded, size: 20, color: ChatColors.textMuted.withValues(alpha: 0.85)),
                                          onSelected: (v) {
                                            if (v == 'delete') {
                                              _confirmDelete(context, s['id'] as String);
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
                              ),
                            );
                          },
                        ),
            ),
            const Divider(height: 1, color: ChatColors.dividerMain),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: ChatColors.subBg,
                foregroundColor: ChatColors.accentBlue,
                child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              title: const Text(
                '账号与设置',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: ChatColors.textPrimary),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (username.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w500, color: ChatColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  const Text(
                    '偏好设置、默认模型与安全',
                    style: TextStyle(color: ChatColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: ChatColors.textMuted, size: 22),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
