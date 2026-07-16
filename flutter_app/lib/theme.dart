import 'package:flutter/material.dart';

/// 앱 공통 색상 팔레트 — 차분한 딥블루 + 뉴트럴 그레이.
/// 교육 서비스다운 신뢰감 있는 톤으로, 상태 색(성공/경고/위험)을 분리해 사용한다.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF3B5BDB); // 딥 인디고블루
  static const primaryDark = Color(0xFF2F4BC0);
  static const primarySoft = Color(0xFFEDF2FF); // 프라이머리 배경 틴트

  static const success = Color(0xFF0CA678); // 완료/정답
  static const successSoft = Color(0xFFE6FCF5);
  static const danger = Color(0xFFE03131); // 오답/경고 알림
  static const dangerSoft = Color(0xFFFFF5F5);
  static const warning = Color(0xFFE8590C);
  static const warningSoft = Color(0xFFFFF4E6);

  static const ink = Color(0xFF1B2437); // 본문 텍스트
  static const inkSoft = Color(0xFF6B7280); // 보조 텍스트
  static const border = Color(0xFFE6E8EE); // 카드/입력창 보더
  static const surface = Colors.white;
  static const background = Color(0xFFF6F7F9); // 화면 배경
}

/// 절제된 프로페셔널 테마
///  - 흰 서페이스 + 얇은 보더, 14px 라운딩
///  - 좌측 정렬 앱바, 명확한 타이포 위계
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  const radius14 = BorderRadius.all(Radius.circular(14));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Pretendard',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Pretendard',
      ),
      iconTheme: IconThemeData(color: AppColors.ink),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: radius14,
        side: BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape:
            const RoundedRectangleBorder(borderRadius: radius14),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFamily: 'Pretendard',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape:
            const RoundedRectangleBorder(borderRadius: radius14),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Pretendard',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.inkSoft),
      helperStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primarySoft,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(
        fontSize: 13.5,
        fontFamily: 'Pretendard',
        color: AppColors.ink,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Pretendard',
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}
