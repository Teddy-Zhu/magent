import 'package:flutter/material.dart';
import 'package:magent_app/core/theme/theme.dart';

/// 三种 Pill 风格：
/// * tonal —— 弱底色（默认，类似 secondaryContainer 派生）
/// * outlined —— 仅边框
/// * solid —— 主色实心（语义最强）
enum AppPillVariant { tonal, outlined, solid }

class AppPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final AppPillVariant variant;
  final double maxWidth;

  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.variant = AppPillVariant.tonal,
    this.maxWidth = 120,
  });

  /// 用语义状态色生成的 Pill。
  factory AppPill.status({
    Key? key,
    required String label,
    required StatusPalette palette,
    IconData? icon,
    double maxWidth = 96,
  }) {
    return AppPill(
      key: key,
      label: label,
      icon: icon,
      color: palette.foreground,
      variant: AppPillVariant.tonal,
      maxWidth: maxWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    Color background;
    Color foreground;
    Color? border;

    switch (variant) {
      case AppPillVariant.tonal:
        background = base.withValues(alpha: 0.12);
        foreground = base;
        border = null;
        break;
      case AppPillVariant.outlined:
        background = Colors.transparent;
        foreground = base;
        border = base.withValues(alpha: 0.45);
        break;
      case AppPillVariant.solid:
        background = base;
        foreground = scheme.onPrimary;
        border = null;
        break;
    }

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.rsm,
        border: border != null ? Border.all(color: border, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
