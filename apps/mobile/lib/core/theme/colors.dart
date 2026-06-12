import 'package:flutter/material.dart';

/// Qubix dark-first color palette — developer-native aesthetic.
class QubixColors {
  QubixColors._();

  // ── Base ──
  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF1A1A22);
  static const Color surfaceLight = Color(0xFF24242E);
  static const Color surfaceHighlight = Color(0xFF2E2E3A);

  // ── Primary ──
  static const Color primary = Color(0xFF7C5CFC);
  static const Color primaryLight = Color(0xFF9D85FD);
  static const Color primaryDark = Color(0xFF5A3DD6);

  // ── Accent ──
  static const Color accent = Color(0xFF00D9FF);
  static const Color accentDim = Color(0xFF00A3BF);

  // ── Text ──
  static const Color textPrimary = Color(0xFFEAEAF0);
  static const Color textSecondary = Color(0xFF9494A8);
  static const Color textTertiary = Color(0xFF5E5E72);
  static const Color textInverse = Color(0xFF0F0F12);

  // ── Status ──
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Agent connectors ──
  static const Color openai = Color(0xFF10A37F);
  static const Color anthropic = Color(0xFFD97706);
  static const Color webhook = Color(0xFF6366F1);
  static const Color echo = Color(0xFF8B5CF6);

  // ── Misc ──
  static const Color divider = Color(0xFF2A2A36);
  static const Color shimmer = Color(0xFF2E2E3A);
  static const Color overlay = Color(0x800F0F12);

  /// Get color for a connector type name.
  static Color connectorColor(String type) {
    switch (type.toLowerCase()) {
      case 'openai':
        return openai;
      case 'anthropic':
        return anthropic;
      case 'webhook':
        return webhook;
      case 'echo':
        return echo;
      default:
        return primary;
    }
  }
}
