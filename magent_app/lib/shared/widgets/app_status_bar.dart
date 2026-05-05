import 'package:flutter/material.dart';

/// 卡片左侧 4px 状态色条（用于 running session 卡片等）。
/// 通常配合 IntrinsicHeight + Row 使用。
class AppStatusBar extends StatelessWidget {
  final Color color;
  final double width;
  final BorderRadius? borderRadius;

  const AppStatusBar({
    super.key,
    required this.color,
    this.width = 4,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
    );
  }
}
