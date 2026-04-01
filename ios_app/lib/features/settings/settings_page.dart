import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/format/error_messages.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/app_dialogs.dart';
import '../../core/ui/app_grouped_surface.dart';
import '../../core/ui/app_section_header.dart';
import '../../core/ui/model_selector_sheet.dart';
import '../auth/auth_controller.dart';
import 'settings_api_endpoint_section.dart';
import 'settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<SettingsController>().load());
  }

  Future<void> _pickDefaultModel(SettingsController s) async {
    await showModelSelectorSheet(
      context,
      selected: s.defaultModel,
      onSelected: (m) {
        final settings = context.read<SettingsController>();
        settings.setDefaultModel(m).then((_) {
          if (!context.mounted) return;
          if (settings.error == null) {
            appRootMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('设置已保存')));
          }
        });
      },
      onOpenSettings: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        children: [
          const AppSectionHeader(label: '账号'),
          AppGroupedSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    child: const Icon(Icons.person_rounded, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('已登录账号', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          auth.me?['username']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '当前正在使用的账号',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SettingsApiEndpointSection(),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(label: '偏好'),
          AppGroupedSurface(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
              title: const Text('默认使用模型', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${s.defaultModel.label}\n新对话将优先使用该模型',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: s.loading ? null : () => _pickDefaultModel(s),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(label: '安全'),
          AppGroupedSurface(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_rounded, color: AppColors.primary),
                  title: const Text('修改登录密码'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => const _ChangePasswordDialog(),
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                  title: const Text('退出当前账号', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final ok = await showAppConfirmDialog(
                      context,
                      title: '退出登录？',
                      message: '退出后需要重新登录才能继续使用。',
                      confirmLabel: '退出登录',
                      isDanger: true,
                    );
                    if (ok == true && context.mounted) {
                      await context.read<AuthController>().logout();
                      appRootMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('已退出登录')));
                    }
                  },
                ),
              ],
            ),
          ),
          if (s.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Text(s.error!, style: const TextStyle(color: AppColors.errorText, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<SettingsController>().changePassword(oldPassword: _old.text, newPassword: _new.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已修改')));
    } catch (e) {
      setState(() => _error = describeErrorForUser(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: const Text('修改登录密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _old,
            decoration: const InputDecoration(labelText: '当前密码', prefixIcon: Icon(Icons.lock_outline_rounded)),
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _new,
            decoration: const InputDecoration(
              labelText: '新密码（不少于 8 位）',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
            obscureText: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.errorBorder),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.errorText, fontSize: 13)),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
