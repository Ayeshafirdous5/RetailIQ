import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

class AppSpacing {
  const AppSpacing._();

  static const x4 = 4.0;
  static const x8 = 8.0;
  static const x12 = 12.0;
  static const x16 = 16.0;
  static const x20 = 20.0;
  static const x24 = 24.0;
  static const x28 = 28.0;
  static const x32 = 32.0;

  static EdgeInsets pagePadding(AppLayoutSize layoutSize) {
    final horizontal = switch (layoutSize) {
      AppLayoutSize.mobile => x16,
      AppLayoutSize.tablet => x24,
      AppLayoutSize.desktop => x32,
    };
    return EdgeInsets.fromLTRB(horizontal, x12, horizontal, x32);
  }
}
