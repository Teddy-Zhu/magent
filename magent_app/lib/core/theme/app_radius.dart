import 'package:flutter/material.dart';

/// 全局统一的圆角令牌。所有 widget 应优先使用这里的值。
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static BorderRadius get rxs => BorderRadius.circular(xs);
  static BorderRadius get rsm => BorderRadius.circular(sm);
  static BorderRadius get rmd => BorderRadius.circular(md);
  static BorderRadius get rlg => BorderRadius.circular(lg);
  static BorderRadius get rxl => BorderRadius.circular(xl);
  static BorderRadius get rpill => BorderRadius.circular(pill);

  /// 顶部圆角的 BottomSheet。
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
}
