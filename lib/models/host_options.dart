import 'package:material_ui/material_ui.dart';

/// Optional metadata override for the About screen when embedded inside a host app
/// so `PackageInfo.fromPlatform()` does not report the host app's version.
@immutable
class SetAndSitAboutInfo {
  final String? appName;
  final String? version;
  final String? buildNumber;
  final String? badgeLabel;

  const SetAndSitAboutInfo({
    this.appName,
    this.version,
    this.buildNumber,
    this.badgeLabel,
  });
}

/// Host integration options adapting Set&Sit when run standalone or embedded
/// inside a parent container (such as Villagers Ally).
@immutable
class SetAndSitHostOptions {
  final ThemeMode? themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final int? fontSizePx;
  final ValueChanged<int>? onFontSizePxChanged;
  final bool? showDisplaySettings;
  final bool showAbout;
  final SetAndSitAboutInfo? aboutInfo;
  final bool allowDeveloperMode;
  final VoidCallback? onExitModule;

  const SetAndSitHostOptions({
    this.themeMode,
    this.onThemeModeChanged,
    this.fontSizePx,
    this.onFontSizePxChanged,
    this.showDisplaySettings,
    this.showAbout = true,
    this.aboutInfo,
    this.allowDeveloperMode = true,
    this.onExitModule,
  });

  bool get effectiveShowDisplaySettings =>
      showDisplaySettings ??
      (onThemeModeChanged != null || onFontSizePxChanged != null);
}
