import 'package:flutter/material.dart';

/// Official light palette from documentation/design-system/tokens.json.
/// Keep semantic accents separate from their readable text foregrounds:
/// mint, amber and coral are not suitable for small text on light surfaces.
abstract final class AppPalette {
  static const black = Color(0xFF000000);
  static const deepOlive = Color(0xFF403D2D);
  static const olive = Color(0xFF605B44);
  static const warmKhaki = Color(0xFF80795A);
  static const sandGold = Color(0xFFC0B587);
  static const paleCream = Color(0xFFF5EFCF);

  // Light Mode Surfaces & Containers
  static const scaffold = Color(0xFFF8F8F5);
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);

  // Clean Neutral Containers (replaces heavy yellow/cream on icons, badges, & chips)
  static const surfaceBadge = Color(0xFFEDEFEB);
  static const surfaceBadgeSecondary = Color(0xFFE2E5E1);

  // Dark Mode Surfaces & Identity
  static const darkScaffold = Color(0xFF0D1117);
  static const darkCard = Color(0xFF161B22);
  static const darkCardBorder = Color(0xFF262D38);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextMuted = Color(0xFF64748B);
  static const darkPrimary = Color(0xFFE2E8F0);
  static const darkPrimaryContainer = Color(0xFF1E293B);
  static const darkSecondary = Color(0xFF94A3B8);
  static const darkSecondaryContainer = Color(0xFF1B2028);

  // Semantic Status
  static const success = Color(0xFF10B981);
  static const successContainer = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const warningContainer = Color(0xFFFEF3C7);
  static const elevated = Color(0xFFF97316);
  static const elevatedContainer = Color(0xFFFFEDD5);
  static const error = Color(0xFFEF4444);
  static const errorContainer = Color(0xFFFEE2E2);

  // Category Semantics for Footprint Map & Badges
  static const social = Color(0xFF3B82F6);
  static const socialContainer = Color(0xFFEFF6FF);
  static const contact = Color(0xFF0D9488);
  static const contactContainer = Color(0xFFF0FDFA);
  static const broker = Color(0xFF6366F1);
  static const brokerContainer = Color(0xFFEEF2FF);
  static const breaches = Color(0xFFDC2626);
  static const breachesContainer = Color(0xFFFEF2F2);
}
