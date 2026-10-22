import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand Colors ───────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2563EB);       // Rich Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color secondary = Color(0xFF10B981);     // Emerald Green
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);

  static const Color accent = Color(0xFFF59E0B);        // Amber
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentDark = Color(0xFFD97706);

  static const Color danger = Color(0xFFEF4444);        // Red
  static const Color dangerLight = Color(0xFFFCA5A5);

  static const Color warning = Color(0xFFF97316);       // Orange
  static const Color warningLight = Color(0xFFFDBA74);

  // ─── Module Colors ──────────────────────────────────────────────────────────
  static const Color medicineColor = Color(0xFF6366F1);     // Indigo
  static const Color mealColor = Color(0xFFEC4899);         // Pink
  static const Color medicalColor = Color(0xFF14B8A6);      // Teal
  static const Color activityColor = Color(0xFFF59E0B);     // Amber
  static const Color prayerColor = Color(0xFF0EA5E9);       // Sky

  static const Color medicineColorLight = Color(0xFFEEF2FF);
  static const Color mealColorLight = Color(0xFFFDF2F8);
  static const Color medicalColorLight = Color(0xFFF0FDFA);
  static const Color activityColorLight = Color(0xFFFFFBEB);
  static const Color prayerColorLight = Color(0xFFF0F9FF);

  // ─── Light Theme ────────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextHint = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightIcon = Color(0xFF475569);

  // ─── Dark Theme ─────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkDivider = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextHint = Color(0xFF64748B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkIcon = Color(0xFF94A3B8);

  // ─── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient medicineGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mealGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient medicalGradient = LinearGradient(
    colors: [Color(0xFF14B8A6), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient activityGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient prayerGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient homeHeaderGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}