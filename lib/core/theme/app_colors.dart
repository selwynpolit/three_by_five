import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Canvas & surfaces ───────────────────────────────────────────────────────
  static const canvas = Color(0xFFF5F2EA);
  static const sidebarBg = Color(0xFFECE8DF);
  static const cardSurface = Color(0xFFFDFBF6); // reverted — user wants original card color

  // ── App canvas (casino-table green behind the cards) ─────────────────────────
  static const appBackground = Color(0xFF3A5544);

  // ── Borders & dividers ──────────────────────────────────────────────────────
  static const cardBorder = Color(0xFFDDD8CE);
  static const divider = Color(0xFFDFDAD0);
  static const sidebarDivider = Color(0xFFD5D0C6);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF2A2320);
  static const textSecondary = Color(0xFF706660);
  static const textTertiary = Color(0xFF9E9892);
  static const textDisabled = Color(0xFFBDB8B2);
  static const textInverse = Color(0xFFFDFBF6);
  static const textCompleted = Color(0xFFB5AFA8);

  // ── Accent ─ ink-blue ────────────────────────────────────────────────────────
  static const accent = Color(0xFF3D5A80);
  static const accentLight = Color(0xFFE6EDF5);
  static const accentMuted = Color(0xFF8FAAC8);

  // ── Sidebar states ──────────────────────────────────────────────────────────
  static const sidebarSelected = Color(0xFFDDD8CE);
  static const sidebarHover = Color(0xFFE4DFDA);
  static const sidebarViewSelected = Color(0xFFE6EDF5);

  // ── Priority ────────────────────────────────────────────────────────────────
  static const priorityHigh = Color(0xFFD64545);
  static const priorityLow = Color(0xFF8FA8C0);

  // ── Due-date chips ──────────────────────────────────────────────────────────
  static const overdueText = Color(0xFFC83E3E);
  static const overdueBg = Color(0xFFFFF0F0);
  static const dueTodayText = Color(0xFFAB7318);
  static const dueTodayBg = Color(0xFFFFF8E6);
  static const dueFutureText = Color(0xFF3D5A80);
  static const dueFutureBg = Color(0xFFEDF2F8);

  // ── Tag chips ───────────────────────────────────────────────────────────────
  static const tagBg = Color(0xFFEDF2F8);
  static const tagText = Color(0xFF3D5A80);

  // ── Stack color palette (8 predefined choices) ──────────────────────────────
  static const stackPalette = <Color>[
    Color(0xFF3D5A80), // ink blue  (default)
    Color(0xFF4A7C59), // forest green
    Color(0xFF8B5E3C), // warm brown
    Color(0xFF7B4F9E), // soft purple
    Color(0xFFB05E3C), // terracotta
    Color(0xFF3C7B8B), // teal
    Color(0xFFC49A3C), // warm gold
    Color(0xFF8A4A6B), // dusty rose
  ];
}
