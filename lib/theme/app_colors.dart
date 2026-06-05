import 'package:flutter/material.dart';

class AppColors {
  // ── 기본 배경 ───────────────────────────────────────────────────────────────
  static const Color background = Colors.white;
  static const Color surfaceSubtle = Color(0xFFFAFAFD); // 섹션 구분 배경

  // ── Lavender (테두리·포인트) ─────────────────────────────────────────────────
  static const Color lavender = Color(0xFF7B6FD4);
  static const Color lavenderBg = Color(0xFFF0EEFF);
  static const Color lavenderLight = Color(0xFFF7F5FF);
  static const Color lavenderBorder = Color(0xFFC4BCE8);
  static const Color lavenderDark = Color(0xFF4A3FA8);
  static const Color lavenderText = Color(0xFF3A3080);

  // ── 상태 컬러 ────────────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFE24B4A);
  static const Color dangerBg = Color(0xFFFDEEEE);
  static const Color warning = Color(0xFFEF9F27);
  static const Color warningBg = Color(0xFFFEF3E2);
  static const Color success = Color(0xFF3B9E72);
  static const Color successBg = Color(0xFFE8F5E9);

  // ── 텍스트 ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF2C2C2A);
  static const Color textSecondary = Color(0xFF888780);
  static const Color textHint = Color(0xFFBBBBBB);

  // ── 카드 / 보더 ─────────────────────────────────────────────────────────────
  static const Color cardBorder = Color(0xFFECE8F8); // 라벤더 계열 테두리
  static const Color divider = Color(0xFFECE8F8);
  static const Color white = Colors.white;

  // ── 약봉투 색상 팔레트 ────────────────────────────────────────────────────────
  static const List<Color> bagColors = [
    Color(0xFF7B6FD4), // 라벤더
    Color(0xFF4A9EE8), // 블루
    Color(0xFF3B9E72), // 그린
    Color(0xFFE24B4A), // 레드
    Color(0xFFEF9F27), // 앰버
    Color(0xFFD4537E), // 핑크
  ];

  static const List<String> bagColorLabels = [
    '라벤더', '블루', '그린', '레드', '앰버', '핑크',
  ];
}
