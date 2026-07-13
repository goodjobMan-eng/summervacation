import 'package:flutter/material.dart';

/// 아이들이 마음을 열 수 있는 따뜻하고 포근한 테마
///  - 크림색 배경 + 살구/코랄 파스텔 톤
///  - 모든 모서리를 크게 둥글려 부드러운 인상
///  - 큼직한 글자와 넉넉한 여백
ThemeData buildKidFriendlyTheme() {
  const seed = Color(0xFFFF8A65); // 따뜻한 코랄
  const cream = Color(0xFFFFF8EF); // 크림색 배경
  final scheme = ColorScheme.fromSeed(seedColor: seed);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: cream,
    fontFamily: 'Pretendard',
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Color(0xFF5D4037),
        fontSize: 19,
        fontWeight: FontWeight.w700,
        fontFamily: 'Pretendard',
      ),
      iconTheme: IconThemeData(color: Color(0xFF5D4037)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFFFE4CC)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Pretendard',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFFCCA8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFFCCA8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFFFE0B2),
      side: const BorderSide(color: Color(0xFFFFCCA8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontFamily: 'Pretendard',
        color: Color(0xFF5D4037),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFFE0B2),
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Pretendard',
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
