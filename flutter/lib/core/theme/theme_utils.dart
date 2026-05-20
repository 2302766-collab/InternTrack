import 'package:flutter/material.dart';

extension AppThemeX on ThemeData {
  bool get isDarkMode => brightness == Brightness.dark;

  Color get primaryTextColor =>
      textTheme.titleLarge?.color ?? colorScheme.onSurface;

  Color get secondaryTextColor =>
      textTheme.bodyMedium?.color ?? colorScheme.onSurfaceVariant;

  Color get panelColor => colorScheme.surface;

  Color get subtlePanelColor => isDarkMode
      ? colorScheme.surfaceContainerHighest
      : const Color(0xFFF8FAFC);

  Color get softPanelColor =>
      isDarkMode ? colorScheme.surfaceContainerHigh : const Color(0xFFF2F4F7);

  Color get accentPanelColor => isDarkMode
      ? colorScheme.primary.withValues(alpha: 0.18)
      : const Color(0xFFEFF8FF);

  Color get warningPanelColor =>
      isDarkMode ? const Color(0xFF4A3413) : const Color(0xFFFFF4E5);

  Color get borderSubtleColor =>
      dividerColor.withValues(alpha: isDarkMode ? 0.9 : 1);

  Color get shadowColorSoft => isDarkMode
      ? Colors.black.withValues(alpha: 0.16)
      : const Color(0x120F172A);
}
