import 'dart:async';
import 'dart:io' show Platform; // <-- 플랫폼 확인을 위해 추가됨
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb; // <-- 웹 환경 확인을 위해 추가됨
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:noise_meter/noise_meter.dart';

// 기존 임포트 유지
import 'core/theme/app_theme.dart';
import 'features/auth/login/login_page.dart';
import 'features/auth/signup/signup_page.dart';
import 'features/detail/detail_page.dart';
import 'features/home/home_page.dart';
import 'features/mypage/mypage_page.dart';
import 'features/settings/settings_page.dart';
import 'routes/app_routes.dart';

// 새로 추가된 NoiseTracker 임포트 (경로 확인 필수!)
import 'core/services/noise_tracker.dart';

// --- 백그라운드 서비스 설정 시작 ---

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // 앱 켤 때가 아니라 사용자가 버튼 누를 때 시작
      isForegroundMode: true,
      notificationChannelId: 'babysense_noise',
      initialNotificationTitle: 'BabySense 수면 모드',
      initialNotificationContent: '수면 소음을 측정하기 위해 대기 중입니다.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  NoiseMeter noiseMeter = NoiseMeter();
  NoiseTracker noiseTracker = NoiseTracker();
  StreamSubscription<NoiseReading>? noiseSubscription;

  try {
    noiseSubscription = noiseMeter.noise.listen((NoiseReading noiseReading) {
      noiseTracker.onNoiseLevelChanged(noiseReading.meanDecibel);

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'BabySense 수면 소음 측정 중',
          content: '현재 소음: ${noiseReading.meanDecibel.toStringAsFixed(1)} dB',
        );
      }
    });
  } catch (err) {
    debugPrint('백그라운드 마이크 에러: $err');
  }
}

// --- 백그라운드 서비스 설정 끝 ---

void main() async {
  // Flutter 엔진 초기화 (필수)
  WidgetsFlutterBinding.ensureInitialized();

  // ★ 방어 코드 추가: 웹이 아니고, 안드로이드나 iOS일 때만 백그라운드 서비스 초기화
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await initializeService();
    } catch (e) {
      debugPrint('백그라운드 서비스 초기화 실패: $e');
    }
  }

  // 앱 실행
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BabySence',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.signup: (context) => const SignupPage(),
        AppRoutes.home: (context) => const HomePage(),
        AppRoutes.detail: (context) => const DetailPage(),
        AppRoutes.mypage: (context) => const MyPagePage(),
        AppRoutes.settings: (context) => const SettingsPage(),
      },
    );
  }
}