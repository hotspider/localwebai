import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/app_grouped_surface.dart';
import '../../core/ui/app_section_header.dart';
import 'legal_documents.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<String> _loadVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final build = info.buildNumber.trim();
    if (version.isEmpty && build.isEmpty) return '—';
    if (version.isEmpty) return 'Build $build';
    if (build.isEmpty) return version;
    return '$version ($build)';
  }

  void _openMarkdown(BuildContext context, {required String title, required String markdown}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MarkdownDocPage(title: title, markdown: markdown),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        children: [
          const AppSectionHeader(label: '应用信息'),
          AppGroupedSurface(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              title: const Text('版本号'),
              subtitle: FutureBuilder<String>(
                future: _loadVersionLabel(),
                builder: (context, snap) {
                  final text = (snap.data ?? '读取中…');
                  return Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textMuted));
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(label: '协议与政策'),
          AppGroupedSurface(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.article_outlined, color: AppColors.primary),
                  title: const Text('使用条款'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () => _openMarkdown(context, title: '使用条款', markdown: kTermsOfUseMarkdown),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () => _openMarkdown(context, title: '隐私政策', markdown: kPrivacyPolicyMarkdown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownDocPage extends StatelessWidget {
  const _MarkdownDocPage({required this.title, required this.markdown});

  final String title;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: Text(title)),
      body: AppGroupedSurface(
        child: Markdown(
          padding: const EdgeInsets.all(AppSpacing.lg),
          data: markdown,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
            h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            blockquote: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

