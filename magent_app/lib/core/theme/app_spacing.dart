import 'package:flutter/widgets.dart';

/// 全局统一的间距令牌（4 倍数体系，但保留 6 这一中间值）。
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  // 常用预制 EdgeInsets，避免散落。
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(lg, sm, lg, xxl);
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md - 2,
  );
  static const EdgeInsets tilePadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm + 2,
  );
  static const EdgeInsets pillPadding = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: 3,
  );
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(lg, sm, lg, xxl);

  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);

  static const SizedBox vGapXs = SizedBox(height: xs);
  static const SizedBox vGapSm = SizedBox(height: sm);
  static const SizedBox vGapMd = SizedBox(height: md);
  static const SizedBox vGapLg = SizedBox(height: lg);
  static const SizedBox vGapXl = SizedBox(height: xl);

  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);
}
