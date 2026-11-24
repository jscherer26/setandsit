/// Pure stateless display preference constants and normalization helpers.
class DisplayPreferences {
  DisplayPreferences._();

  static const List<int> allowedFontSizes = [14, 16, 18, 20, 22, 24];
  static const int defaultFontSizePx = 18;

  /// Normalizes a requested font size to the nearest 2px stop in [14..24].
  static int normalizeFontSizePx(int? value) {
    if (value == null) return defaultFontSizePx;
    final clamped = value.clamp(allowedFontSizes.first, allowedFontSizes.last);
    return ((clamped - allowedFontSizes.first) / 2).round() * 2 +
        allowedFontSizes.first;
  }
}
