import 'package:flutter/material.dart';

/// 圆点状态指示。`pulse` 为 true 时叠加 1.5s 循环的呼吸动画（用于 running）。
class AppStatusDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool pulse;

  const AppStatusDot({
    super.key,
    required this.color,
    this.size = 8,
    this.pulse = false,
  });

  @override
  State<AppStatusDot> createState() => _AppStatusDotState();
}

class _AppStatusDotState extends State<AppStatusDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _startPulse();
  }

  @override
  void didUpdateWidget(covariant AppStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) {
      if (widget.pulse) {
        _startPulse();
      } else {
        _controller?.dispose();
        _controller = null;
      }
    }
  }

  void _startPulse() {
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
      ),
    );
    if (_controller == null) return dot;
    return AnimatedBuilder(
      animation: _controller!,
      builder: (_, child) {
        final t = _controller!.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.4 - 0.3 * t,
              child: Container(
                width: widget.size + 8 * t,
                height: widget.size + 8 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: dot,
    );
  }
}
