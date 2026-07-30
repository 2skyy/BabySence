import '../../core/services/baby_service.dart';
import '../../routes/app_routes.dart';

/// 로그인/회원가입 성공 직후 이동할 화면을 정합니다.
///
/// 등록된 아이가 없으면 온보딩을 먼저 거칩니다. 화면 대부분이 baby_id를
/// 전제로 하기 때문에, 아이 없이 홈에 들어가면 빈 화면만 보게 됩니다.
Future<String> nextRouteAfterSignIn() async {
  try {
    final baby = await BabyService.loadCurrent();
    return baby == null ? AppRoutes.onboarding : AppRoutes.home;
  } catch (_) {
    // 아이 조회에 실패해도 로그인 자체는 성공한 상태이므로 홈으로 보냅니다.
    return AppRoutes.home;
  }
}
