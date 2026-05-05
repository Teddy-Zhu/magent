import 'package:flutter/material.dart';
import 'package:magent_app/core/theme/theme.dart';

/// icon container 的颜色族选项。
enum AppListTileTone { primary, secondary, tertiary, neutral }

/// 卡片式 ListTile：左侧带圆角图标容器、主标题 + 副标题、可选 trailing。
/// 不自带 Card 包装，调用方把它放进 Card / AppSection 内。
class AppListTile extends StatelessWidget {
  final IconData? leadingIcon;
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AppListTileTone tone;
  final bool showChevron;
  final EdgeInsets? padding;

  const AppListTile({
    super.key,
    this.leadingIcon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone = AppListTileTone.primary,
    this.showChevron = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (containerColor, iconColor) = _toneColors(scheme);

    final Widget? leadingWidget = leading ??
        (leadingIcon != null
            ? Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: AppRadius.rsm,
                ),
                child: Icon(leadingIcon, size: 19, color: iconColor),
              )
            : null);

    final trailingWidget = trailing ??
        (showChevron
            ? Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              )
            : null);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rmd,
      child: Padding(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: 8),
              trailingWidget,
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color) _toneColors(ColorScheme scheme) {
    switch (tone) {
      case AppListTileTone.primary:
        return (
          scheme.primaryContainer.withValues(alpha: 0.6),
          scheme.onPrimaryContainer,
        );
      case AppListTileTone.secondary:
        return (
          scheme.secondaryContainer.withValues(alpha: 0.7),
          scheme.onSecondaryContainer,
        );
      case AppListTileTone.tertiary:
        return (
          scheme.tertiaryContainer.withValues(alpha: 0.7),
          scheme.onTertiaryContainer,
        );
      case AppListTileTone.neutral:
        return (
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
        );
    }
  }
}
