class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';

  /// 로그인 직후 등록된 아이가 없으면 여기로 보냅니다.
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String detail = '/detail';
  static const String mypage = '/mypage';
  static const String settings = '/settings';

  // 수유 기록 페이지
  static const String feedingRecord = '/feeding-record';

  // 체온 기록 페이지
  static const String temperatureRecord = '/temperature-record';

  // 배변 기록 페이지
  static const String diaperRecord = '/diaper-record';
}