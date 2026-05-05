import 'package:flutter/material.dart';

/// 单一状态调色板：foreground 用于文字/图标，background 为弱底色，border 为描边。
@immutable
class StatusPalette {
  final Color foreground;
  final Color background;
  final Color border;

  const StatusPalette({
    required this.foreground,
    required this.background,
    required this.border,
  });

  StatusPalette copyWith({Color? foreground, Color? background, Color? border}) {
    return StatusPalette(
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      border: border ?? this.border,
    );
  }

  static StatusPalette lerp(StatusPalette a, StatusPalette b, double t) {
    return StatusPalette(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      background: Color.lerp(a.background, b.background, t)!,
      border: Color.lerp(a.border, b.border, t)!,
    );
  }

  /// 由一个语义色生成弱底/边框版本。
  factory StatusPalette.fromSeed(Color seed, {required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return StatusPalette(
      foreground: isDark ? _lighten(seed, 0.18) : _darken(seed, 0.08),
      background: seed.withValues(alpha: isDark ? 0.18 : 0.12),
      border: seed.withValues(alpha: isDark ? 0.36 : 0.28),
    );
  }
}

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

/// 应用层语义色，覆盖 running / success / warning / error / info / neutral。
/// 通过 `Theme.extensions` 注入，业务用 `AppStatusColors.of(context).running` 取色。
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  final StatusPalette running;
  final StatusPalette success;
  final StatusPalette warning;
  final StatusPalette error;
  final StatusPalette info;
  final StatusPalette neutral;

  const AppStatusColors({
    required this.running,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.neutral,
  });

  factory AppStatusColors.fromScheme(ColorScheme scheme) {
    final brightness = scheme.brightness;
    return AppStatusColors(
      running: StatusPalette.fromSeed(
        const Color(0xFF22C55E), // emerald-500
        brightness: brightness,
      ),
      success: StatusPalette.fromSeed(
        scheme.primary,
        brightness: brightness,
      ),
      warning: StatusPalette.fromSeed(
        const Color(0xFFF59E0B), // amber-500
        brightness: brightness,
      ),
      error: StatusPalette.fromSeed(
        scheme.error,
        brightness: brightness,
      ),
      info: StatusPalette.fromSeed(
        const Color(0xFF3B82F6), // blue-500
        brightness: brightness,
      ),
      neutral: StatusPalette(
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHighest.withValues(
          alpha: brightness == Brightness.dark ? 0.6 : 0.7,
        ),
        border: scheme.outlineVariant.withValues(alpha: 0.55),
      ),
    );
  }

  @override
  AppStatusColors copyWith({
    StatusPalette? running,
    StatusPalette? success,
    StatusPalette? warning,
    StatusPalette? error,
    StatusPalette? info,
    StatusPalette? neutral,
  }) {
    return AppStatusColors(
      running: running ?? this.running,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      running: StatusPalette.lerp(running, other.running, t),
      success: StatusPalette.lerp(success, other.success, t),
      warning: StatusPalette.lerp(warning, other.warning, t),
      error: StatusPalette.lerp(error, other.error, t),
      info: StatusPalette.lerp(info, other.info, t),
      neutral: StatusPalette.lerp(neutral, other.neutral, t),
    );
  }

  static AppStatusColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppStatusColors>();
    return ext ??
        AppStatusColors.fromScheme(Theme.of(context).colorScheme);
  }
}
