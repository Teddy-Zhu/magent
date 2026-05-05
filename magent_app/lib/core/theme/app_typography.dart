import 'package:flutter/material.dart';

/// 在 Material 3 默认 textTheme 上叠加更舒适的中文行高与字重，避免在中文移动端"太挤"。
class AppTypography {
  AppTypography._();

  static TextTheme apply(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(height: 1.2, fontWeight: FontWeight.w700),
      displayMedium: base.displayMedium?.copyWith(height: 1.2, fontWeight: FontWeight.w700),
      displaySmall: base.displaySmall?.copyWith(height: 1.25, fontWeight: FontWeight.w700),
      headlineLarge: base.headlineLarge?.copyWith(height: 1.25, fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(height: 1.3, fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(height: 1.3, fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(height: 1.3, fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(height: 1.35, fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(height: 1.35, fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(height: 1.4),
      labelLarge: base.labelLarge?.copyWith(
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelMedium: base.labelMedium?.copyWith(
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelSmall: base.labelSmall?.copyWith(
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
