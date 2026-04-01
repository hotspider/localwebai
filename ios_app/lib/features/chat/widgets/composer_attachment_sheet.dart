import 'package:flutter/material.dart';

import 'chat_toast.dart';
import 'composer_attachment_action_cancel.dart';
import 'composer_attachment_action_item.dart';

Future<void> showComposerAttachmentSheet(
  BuildContext context, {
  required Future<void> Function() onCamera,
  required Future<void> Function() onGallery,
  required Future<void> Function() onUploadText,
}) async {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: false,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color.fromRGBO(15, 23, 42, 0.28),
    builder: (ctx) {
      Future<void> runAction(Future<void> Function() fn, String failMessage) async {
        Navigator.pop(ctx);
        try {
          await fn();
        } catch (_) {
          if (context.mounted) showChatToast(context, failMessage);
        }
      }

      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(15, 23, 42, 0.08),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择添加方式',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                ),
              ),
              const SizedBox(height: 12),
              ComposerAttachmentActionItem(
                icon: Icons.photo_camera_outlined,
                label: '拍照',
                onTap: () => runAction(onCamera, '无法打开相机，请检查权限设置'),
              ),
              const SizedBox(height: 8),
              ComposerAttachmentActionItem(
                icon: Icons.photo_outlined,
                label: '从本机相册选择',
                onTap: () => runAction(onGallery, '无法打开相册，请稍后重试'),
              ),
              const SizedBox(height: 8),
              ComposerAttachmentActionItem(
                icon: Icons.description_outlined,
                label: '上传文本',
                onTap: () => runAction(onUploadText, '文本上传失败，请重试'),
              ),
              const SizedBox(height: 10),
              ComposerAttachmentActionCancel(onTap: () => Navigator.pop(ctx)),
              SizedBox(height: MediaQuery.paddingOf(ctx).bottom),
            ],
          ),
        ),
      );
    },
  );
}

