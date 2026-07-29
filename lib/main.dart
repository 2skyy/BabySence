import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login/login_page.dart';
import 'features/auth/signup/signup_page.dart';
import 'features/detail/detail_page.dart';
import 'features/home/home_page.dart';
import 'features/mypage/mypage_page.dart';
import 'features/settings/settings_page.dart';
import 'routes/app_routes.dart';

import 'core/services/noise_tracker.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'babysense_noise',
    'BabySense 수면 모드 알림',
    description: '백그라운드에서 선택한 수면 모드가 작동 중임을 알립니다.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'babysense_noise',
      initialNotificationTitle: 'BabySense 수면 모드',
      initialNotificationContent: '원하시는 수면 모드를 선택해 주세요.',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [
        AndroidForegroundType.microphone,
        AndroidForegroundType.mediaPlayback,
      ],
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

  final AudioPlayer audioPlayer = AudioPlayer();
  NoiseTracker noiseTracker = NoiseTracker();

  NoiseMeter? noiseMeter;
  StreamSubscription<NoiseReading>? noiseSubscription;

  bool isNoiseMeasuring = false;
  bool isWhiteNoisePlaying = false;

  // 데시벨 수치 널뛰기 방지용 이동 평균 변수
  double smoothedDb = 0.0;

  void updateNotification() {
    String title = 'BabySense 수면 모드 작동 중';
    String content = '';

    if (isNoiseMeasuring && isWhiteNoisePlaying) {
      content = '소음 측정 중 & 백색소음 재생 중';
    } else if (isNoiseMeasuring) {
      content = '실시간 수면 소음 측정 중...';
    } else if (isWhiteNoisePlaying) {
      content = '아기를 위한 백색소음 재생 중...';
    } else {
      content = '대기 중입니다.';
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: title, content: content);
    }
  }

  void startNoiseMeasurement() {
    if (isNoiseMeasuring) return;

    try {
      noiseMeter = NoiseMeter();
      smoothedDb = 0.0;

      noiseSubscription = noiseMeter!.noise.listen(
            (NoiseReading noiseReading) {
          if (noiseReading.meanDecibel.isInfinite || noiseReading.meanDecibel.isNaN) return;

          double rawDb = noiseReading.meanDecibel;

          // 1. [강력한 오프셋 차감]: 마이크 하울링/증폭을 감쇄하기 위해 15dB 차감
          double adjustedDb = rawDb - 15.0;

          // 2. [노이즈 바닥 제한 (Min Cutoff)]: 방 안의 고요한 환경 수치인 30dB 이하로 떨어지지 않게 평탄화
          if (adjustedDb < 30.0) {
            adjustedDb = 30.0 + (adjustedDb % 2.0);
          }

          // 3. [초둔감 이동 평균 필터]: 이전 수치 85% + 새 수치 15%로 믹싱하여 갑자기 치솟는 수치 억제
          smoothedDb = (smoothedDb == 0.0)
              ? adjustedDb
              : (smoothedDb * 0.85) + (adjustedDb * 0.15);

          // 4. 보정된 수치를 UI 및 서버 버퍼로 전달
          noiseTracker.onNoiseLevelChanged(smoothedDb);
          service.invoke('update_db', {"db": smoothedDb.toStringAsFixed(1)});

          if (service is AndroidServiceInstance && !isWhiteNoisePlaying) {
            service.setForegroundNotificationInfo(
              title: 'BabySense 소음 측정 중',
              content: '현재 소음: ${smoothedDb.toStringAsFixed(1)} dB',
            );
          }
        },
        onError: (Object error) {
          debugPrint('★ 백그라운드 소음 스트림 내부 에러 발생: $error');
          isNoiseMeasuring = false;
          updateNotification();
        },
        cancelOnError: false,
      );

      isNoiseMeasuring = true;
      updateNotification();
    } catch (err) {
      debugPrint('★ 마이크 초기화 단계 치명적 에러: $err');
      isNoiseMeasuring = false;
      updateNotification();
    }
  }

  void stopNoiseMeasurement() {
    try {
      noiseSubscription?.cancel();
      noiseSubscription = null;
      noiseMeter = null;
    } catch (e) {
      debugPrint('소음 중지 중 오류: $e');
    }
    isNoiseMeasuring = false;
    updateNotification();
  }

  // --- UI 신호(이벤트) 리스너 설정 ---

  service.on('startNoiseOnly').listen((event) {
    startNoiseMeasurement();
  });

  service.on('stopNoiseOnly').listen((event) {
    stopNoiseMeasurement();
  });

  service.on('startWhiteNoiseOnly').listen((event) async {
    if (isWhiteNoisePlaying) return;
    isWhiteNoisePlaying = true;
    updateNotification();

    try {
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.play(AssetSource('audio/white_noise.mp3'));
    } catch (e) {
      debugPrint('백색소음 재생 에러: $e');
    }
  });

  service.on('stopWhiteNoiseOnly').listen((event) async {
    try {
      await audioPlayer.stop();
    } catch (e) {
      debugPrint('백색소음 중지 오류: $e');
    }
    isWhiteNoisePlaying = false;
    updateNotification();
  });

  service.on('stopService').listen((event) async {
    try {
      noiseSubscription?.cancel();
      await audioPlayer.stop();
      await audioPlayer.dispose();
    } catch (e) {
      debugPrint('오디오 해제 에러: $e');
    }
    service.stopSelf();
  });
}

// ★ 앱 실행 시 필수 권한 팝업을 띄우는 강화된 권한 함수
Future<void> _requestAppPermissions() async {
  // 1. 마이크 권한 및 알림(상단 바) 권한 요청
  Map<Permission, PermissionStatus> statuses = await [
    Permission.microphone,
    Permission.notification,
  ].request();

  // 2. 만약 마이크 권한이 완전히 거부되어 있다면 설정 페이지 안내 디버그 출력
  if (statuses[Permission.microphone]!.isPermanentlyDenied) {
    debugPrint("★ 마이크 권한이 영구 거부되었습니다. 설정에서 권한을 허용해 주세요.");
    await openAppSettings();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ★ 앱이 완전히 구동되기 전에 시스템 권한 팝업 실행
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await _requestAppPermissions();
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await initializeService();
    } catch (e) {
      debugPrint('백그라운드 서비스 초기화 실패: $e');
    }
  }

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