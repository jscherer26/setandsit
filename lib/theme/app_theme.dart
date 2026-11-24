import 'package:material_ui/material_ui.dart';

/// Legacy static color palette constants retained for reference and light defaults.
class AppColors {
  static const Color background = Color(0xFFF3F3EE);
  static const Color backgroundSand = Color(0xFFECECE5);
  static const Color circleOuterGlow = Color(0xFFE5E7DC);
  static const Color circleBorder = Color(0xFFDFE2D6);
  static const Color white = Color(0xFFFFFFFF);

  static const Color darkOlive = Color(0xFF434C28);
  static const Color darkOlivePressed = Color(0xFF353C20);
  static const Color buttonTextLight = Color(0xFFFAF9F5);

  static const Color pillUnselected = Color(0xFFEAECE3);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x0C000000);
  static const Color cardBorder = Color(0xFFE6E8E0);

  static const Color textBlack = Color(0xFF1F241A);
  static const Color textMuted = Color(0xFF6B7262);
  static const Color textSubtle = Color(0xFF8C9283);

  static const Color sageActive = Color(0xFFA6B79D);
  static const Color roseActive = Color(0xFFD3A2A3);
  static const Color darkBackground = Color(0xFF262826);
  static const Color cardSurface = Color(0xFF353935);
  static const Color errorRed = Color(0xFFD32F2F);

  static const Color systemBlue = Color(0xFF1565C0);
  static const Color customGreen = Color(0xFF2E7D32);
}

/// Semantic and botanical UI tokens exposed as a Material 3 [ThemeExtension].
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color warning;
  final Color muted;
  final Color subtle;
  final Color systemPractice;
  final Color customPractice;
  final Color sandSurface;
  final Color pillUnselected;
  final Color circleOuterGlow;
  final Color circleBorder;
  final Color clockDialSurface;
  final Color desktopFrameBackdrop;

  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.muted,
    required this.subtle,
    required this.systemPractice,
    required this.customPractice,
    required this.sandSurface,
    required this.pillUnselected,
    required this.circleOuterGlow,
    required this.circleBorder,
    required this.clockDialSurface,
    required this.desktopFrameBackdrop,
  });

  static const light = AppSemanticColors(
    success: Color(0xFF2E7D32),
    warning: Color(0xFFD97706),
    muted: Color(0xFF6B7262),
    subtle: Color(0xFF8C9283),
    systemPractice: Color(0xFF1565C0),
    customPractice: Color(0xFF2E7D32),
    sandSurface: Color(0xFFECECE5),
    pillUnselected: Color(0xFFEAECE3),
    circleOuterGlow: Color(0xFFE5E7DC),
    circleBorder: Color(0xFFDFE2D6),
    clockDialSurface: Color(0xFFF3F5F2),
    desktopFrameBackdrop: Color(0xFF1E201E),
  );

  static const dark = AppSemanticColors(
    success: Color(0xFF81C784),
    warning: Color(0xFFFFB74D),
    muted: Color(0xFF9BA394),
    subtle: Color(0xFF7E8678),
    systemPractice: Color(0xFF64B5F6),
    customPractice: Color(0xFF81C784),
    sandSurface: Color(0xFF2B3029),
    pillUnselected: Color(0xFF2A2F28),
    circleOuterGlow: Color(0xFF282E26),
    circleBorder: Color(0xFF3A4336),
    clockDialSurface: Color(0xFF2B3029),
    desktopFrameBackdrop: Color(0xFF111311),
  );

  /// Safely resolves [AppSemanticColors] even when a widget is mounted inside
  /// a bare [MaterialApp] without [AppTheme] configured.
  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? muted,
    Color? subtle,
    Color? systemPractice,
    Color? customPractice,
    Color? sandSurface,
    Color? pillUnselected,
    Color? circleOuterGlow,
    Color? circleBorder,
    Color? clockDialSurface,
    Color? desktopFrameBackdrop,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      systemPractice: systemPractice ?? this.systemPractice,
      customPractice: customPractice ?? this.customPractice,
      sandSurface: sandSurface ?? this.sandSurface,
      pillUnselected: pillUnselected ?? this.pillUnselected,
      circleOuterGlow: circleOuterGlow ?? this.circleOuterGlow,
      circleBorder: circleBorder ?? this.circleBorder,
      clockDialSurface: clockDialSurface ?? this.clockDialSurface,
      desktopFrameBackdrop: desktopFrameBackdrop ?? this.desktopFrameBackdrop,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      systemPractice: Color.lerp(systemPractice, other.systemPractice, t)!,
      customPractice: Color.lerp(customPractice, other.customPractice, t)!,
      sandSurface: Color.lerp(sandSurface, other.sandSurface, t)!,
      pillUnselected: Color.lerp(pillUnselected, other.pillUnselected, t)!,
      circleOuterGlow: Color.lerp(circleOuterGlow, other.circleOuterGlow, t)!,
      circleBorder: Color.lerp(circleBorder, other.circleBorder, t)!,
      clockDialSurface: Color.lerp(clockDialSurface, other.clockDialSurface, t)!,
      desktopFrameBackdrop: Color.lerp(desktopFrameBackdrop, other.desktopFrameBackdrop, t)!,
    );
  }
}

/// Set&Sit Material 3 Light & Dark theme definitions.
class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkOlive,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.darkOlive,
      onPrimary: AppColors.buttonTextLight,
      surface: AppColors.background,
      onSurface: AppColors.textBlack,
      surfaceContainerLow: AppColors.white,
      surfaceContainerHighest: AppColors.backgroundSand,
      outlineVariant: const Color(0xFFE0E3D8),
      error: AppColors.errorRed,
      onError: AppColors.white,
    );

    return _buildTheme(colorScheme, AppSemanticColors.light);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8FA67E),
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.sageActive,
      onPrimary: const Color(0xFF1A2116),
      surface: const Color(0xFF181B17),
      onSurface: const Color(0xFFEAECE6),
      surfaceContainerLow: const Color(0xFF222620),
      surfaceContainerHighest: const Color(0xFF2C3129),
      outlineVariant: const Color(0xFF394035),
      error: const Color(0xFFEF9A9A),
      onError: const Color(0xFF490B0B),
    );

    return _buildTheme(colorScheme, AppSemanticColors.dark);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    AppSemanticColors semantic,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      extensions: [semantic],
    );
  }
}
