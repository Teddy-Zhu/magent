import 'package:flutter/material.dart';
import 'package:magent_app/core/theme/theme.dart';

enum AppLoadingSize { small, medium, large }

/// 统一加载组件。整个 App 应使用此组件替代裸 [CircularProgressIndicator]。
class AppLoading extends StatelessWidget {
  final String? message;
  final AppLoadingSize size;

  const AppLoading({super.key, this.message, this.size = AppLoadingSize.medium});

  double get _dimension {
    switch (size) {
      case AppLoadingSize.small:
        return 18;
      case AppLoadingSize.medium:
        return 28;
      case AppLoadingSize.large:
        return 36;
    }
  }

  double get _stroke {
    switch (size) {
      case AppLoadingSize.small:
        return 2;
      case AppLoadingSize.medium:
        return 2.6;
      case AppLoadingSize.large:
        return 3.4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _dimension,
            height: _dimension,
            child: CircularProgressIndicator(strokeWidth: _stroke),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 卡片骨架占位（list 加载用）。
class AppListSkeleton extends StatelessWidget {
  final int count;
  final double height;

  const AppListSkeleton({super.key, this.count = 5, this.height = 64});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: AppRadius.rmd,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
