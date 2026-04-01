import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_endpoint_store.dart';
import '../../core/config/constants.dart';
import '../../core/config/current_api_base.dart';
import '../../core/storage/secure_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/app_grouped_surface.dart';
import '../../core/ui/app_section_header.dart';

/// 设置页：切换本地 / 公网 / 自定义 API，保存后重启应用树并清除登录 token。
class SettingsApiEndpointSection extends StatefulWidget {
  const SettingsApiEndpointSection({super.key});

  @override
  State<SettingsApiEndpointSection> createState() => _SettingsApiEndpointSectionState();
}

class _SettingsApiEndpointSectionState extends State<SettingsApiEndpointSection> {
  String _mode = 'local';
  final _publicCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _publicCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final mode = await ApiEndpointStore.readMode();
    final pub = await ApiEndpointStore.readPublicUrl();
    final cust = await ApiEndpointStore.readCustomUrl();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _publicCtrl.text = pub;
      _customCtrl.text = cust;
      _loading = false;
    });
  }

  Future<void> _apply() async {
    final custom = _customCtrl.text.trim();
    final pub = _publicCtrl.text.trim();
    if (_mode == 'custom') {
      if (!_looksLikeHttpUrl(custom)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自定义地址需以 http:// 或 https:// 开头')),
        );
        return;
      }
    }
    if (_mode == 'public') {
      if (!_looksLikeHttpUrl(pub)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('公网地址需以 http:// 或 https:// 开头')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final secureStore = context.read<SecureStore>();
    try {
      await ApiEndpointStore.save(
        mode: _mode,
        publicUrl: pub,
        customUrl: custom,
      );
      await secureStore.clearToken();
      if (!mounted) return;
      Phoenix.rebirth(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static bool _looksLikeHttpUrl(String s) {
    final t = s.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final locked = ApiEndpointStore.isLockedByCompileTimeDefine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(label: '接口地址'),
        if (locked) ...[
          AppGroupedSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '当前已通过编译参数锁定 API：${AppConstants.apiBaseUrlFromEnvironment}\n'
                '设置内切换无效；请去掉 --dart-define=API_BASE_URL 后重新运行。',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
              ),
            ),
          ),
        ] else ...[
          AppGroupedSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前生效：${CurrentApiBase.display}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'local', label: Text('本地'), icon: Icon(Icons.laptop_mac_rounded, size: 18)),
                      ButtonSegment(value: 'public', label: Text('公网'), icon: Icon(Icons.cloud_rounded, size: 18)),
                      ButtonSegment(value: 'custom', label: Text('自定义'), icon: Icon(Icons.edit_rounded, size: 18)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  if (_mode == 'public') ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text('公网根地址（无末尾 /）', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _publicCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'http://你的服务器:8000',
                        isDense: true,
                      ),
                    ),
                  ],
                  if (_mode == 'custom') ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text('完整 API 根地址', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'http://192.168.x.x:8000',
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    '应用后将重新加载并退出登录（两套后端账号 token 不通用，需分别登录）。',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _apply,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('应用并重新加载'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
