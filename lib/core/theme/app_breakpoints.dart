enum AppLayoutSize { mobile, tablet, desktop }

class AppBreakpoints {
  const AppBreakpoints._();

  static const tabletMinWidth = 600.0;
  static const desktopMinWidth = 1024.0;

  static AppLayoutSize fromWidth(double width) {
    if (width < tabletMinWidth) return AppLayoutSize.mobile;
    if (width < desktopMinWidth) return AppLayoutSize.tablet;
    return AppLayoutSize.desktop;
  }
}
