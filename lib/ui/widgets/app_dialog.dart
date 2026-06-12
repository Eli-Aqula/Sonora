import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  Widget? content,
  WidgetBuilder? contentBuilder,
  required List<AppDialogAction> actions,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => _AppDialog(
      title: title,
      content: content,
      contentBuilder: contentBuilder,
      actions: actions,
    ),
  );
}

class AppDialogAction {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  const AppDialogAction({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });
}

class _AppDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final WidgetBuilder? contentBuilder;
  final List<AppDialogAction> actions;
  const _AppDialog({
    required this.title,
    this.content,
    this.contentBuilder,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (content != null) ...[
                const SizedBox(height: 12),
                content!,
              ],
              if (contentBuilder != null) ...[
                const SizedBox(height: 16),
                contentBuilder!(context),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _AppDialogButton(action: actions[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDialogButton extends StatelessWidget {
  final AppDialogAction action;
  const _AppDialogButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final danger = action.danger;
    final primary = action.primary;
    final Color border;
    final Color text;
    final Color fill;
    if (danger) {
      border = Colors.red.withValues(alpha: 0.4);
      text = Colors.redAccent;
      fill = Colors.red.withValues(alpha: 0.1);
    } else if (primary) {
      border = Colors.white.withValues(alpha: 0.6);
      text = AppColors.textPrimary;
      fill = Colors.white.withValues(alpha: 0.08);
    } else {
      border = Colors.white.withValues(alpha: 0.18);
      text = AppColors.textSecondary;
      fill = Colors.transparent;
    }
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            action.label,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  const _AppTextField({
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      cursorColor: AppColors.textPrimary,
      style: const TextStyle(
        fontFamily: AppFonts.family,
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: AppFonts.family,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) =>
      _AppTextField(controller: controller, hint: hint, autofocus: autofocus, onSubmitted: onSubmitted);
}
