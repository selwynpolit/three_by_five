import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          onPrimary: AppColors.textInverse,
          secondary: AppColors.accentMuted,
          onSecondary: AppColors.textInverse,
          surface: AppColors.cardSurface,
          onSurface: AppColors.textPrimary,
          outline: AppColors.cardBorder,
        ),
        scaffoldBackgroundColor: AppColors.canvas,
        textTheme: AppTypography.textTheme,
        dividerColor: AppColors.divider,
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 0.5,
          space: 1,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardSurface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppSpacing.cardRadius),
            side: const BorderSide(
                color: AppColors.cardBorder, width: 0.5),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.accent
                  : Colors.transparent),
          checkColor:
              const WidgetStatePropertyAll(AppColors.textInverse),
          side: const BorderSide(
              color: AppColors.cardBorder, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4)),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: AppTypography.textTheme.bodySmall
              ?.copyWith(color: AppColors.textInverse),
          waitDuration: const Duration(milliseconds: 600),
        ),
        scrollbarTheme: const ScrollbarThemeData(
          thumbVisibility: WidgetStatePropertyAll(false),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      );
}
