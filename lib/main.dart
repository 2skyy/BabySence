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

// ★ 백엔드 파이어베이스 및 수파베이스 임포트
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/login/login_page.dart';
import 'features/auth/signup/signup_page.dart';
import 'features/detail/detail_page.dart';
import 'features/shell/main_shell.dart';
import 'features/mypage/mypage_page.dart';
import 'features/onboarding/child_info_page.dart';
import 'features/settings/settings_page.dart';
import 'routes/app_routes.dart';

import 'core/services/noise_tracker.dart';

/// 스마트폰 마이크가 실제보다 크게 잡는 만큼을 빼주는 보정값(dB).
/// 기기마다 달라 경험적으로 정한 값이며, 보정은 이 한 곳에서만 적용합니다.
const double _micOffsetDb = 15.0;

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

  // 플러그인 초기화. 이걸 하지 않으면 iOS에서는 알림이 전혀 뜨지 않습니다.
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // 권한은 _requestAppPermissions에서 따로 받으므로 여기서는 요청하지 않습니다.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

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

  // 백그라운드 서비스는 UI와 다른 isolate에서 돕니다. main()에서 한 초기화는
  // 여기까지 오지 않으므로, 소음을 저장하려면 이 isolate에서 다시 초기화해야 합니다.
  // 로그인 세션은 로컬 저장소에서 자동으로 복원됩니다.
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint('백그라운드 Supabase 초기화 실패(소음 저장 불가): $e');
  }

  final AudioPlayer audioPlayer = AudioPlayer();
  NoiseTracker noiseTracker = NoiseTracker();

  NoiseMeter? noiseMeter;
  StreamSubscription<NoiseReading>? noiseSubscription;

  bool isNoiseMeasuring = false;
  bool isWhiteNoisePlaying = false;

  // 데시벨 수치 널뛰기 방지용 이동 평균 변수.
  // 0.0은 "조용함"이라는 정상 측정값이기도 하므로, 첫 측정 여부는 따로 둡니다.
  double smoothedDb = 0.0;
  bool isFirstReading = true;

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
      isFirstReading = true;

      noiseSubscription = noiseMeter!.noise.listen(
            (NoiseReading noiseReading) {
          if (noiseReading.meanDecibel.isInfinite || noiseReading.meanDecibel.isNaN) return;

          double rawDb = noiseReading.meanDecibel;

          // 1. [오프셋 차감]: 스마트폰 마이크의 증폭분을 상쇄합니다.
          //    보정은 여기 한 곳에서만 합니다. NoiseTracker는 받은 값을 그대로 저장합니다.
          double adjustedDb = rawDb - _micOffsetDb;
          if (adjustedDb < 0) adjustedDb = 0;

          // 2. [이동 평균 필터]: 이전 수치 85% + 새 수치 15%로 갑작스러운 치솟음을 억제합니다.
          smoothedDb = isFirstReading
              ? adjustedDb
              : (smoothedDb * 0.85) + (adjustedDb * 0.15);
          isFirstReading = false;

          // 3. 보정된 수치를 UI와 저장 버퍼에 같은 값으로 전달합니다.
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

    // 버퍼에 남은 로그를 마저 저장하고 수면 기록의 종료 시각을 채웁니다.
    noiseTracker.finish();
  }

  // --- UI 신호(이벤트) 리스너 설정 ---

  service.on('startNoiseOnly').listen((event) {
    // UI에서 고른 밤잠/낮잠 값을 받습니다. 없으면 밤잠으로 봅니다.
    noiseTracker.beginSession(SleepType.parse(event?['sleepType'] as String?));
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
      await noiseTracker.finish();
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
  Map<Permission, PermissionStatus> statuses = await [
    Permission.microphone,
    Permission.notification,
  ].request();

  // 플랫폼에 따라 요청 결과에 항목이 없을 수 있어 ?.로 접근합니다.
  if (statuses[Permission.microphone]?.isPermanentlyDenied ?? false) {
    debugPrint("★ 마이크 권한이 영구 거부되었습니다. 설정에서 권한을 허용해 주세요.");
    await openAppSettings();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. ★ Supabase 초기화
  // 연결 정보가 없으면 여기서 즉시 멈춥니다. 초기화에 실패한 채로 앱을 띄우면
  // 나중에 로그인 화면에서 원인을 알 수 없는 에러가 나기 때문입니다.
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase 연결 정보가 없습니다.\n'
      'env.example.json을 env.json으로 복사해 값을 채운 뒤 아래처럼 실행하세요.\n'
      '  flutter run --dart-define-from-file=env.json',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // 2. ★ Firebase 초기화 (google-services.json 기반)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp();
      debugPrint("🔴 Firebase 초기화 성공!");
    } catch (e) {
      debugPrint("🔴 Firebase 초기화 실패: $e");
    }
  }

  // 3. 앱 시스템 권한 및 백그라운드 서비스 시작
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await _requestAppPermissions();
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
      // 저장된 세션이 있으면 로그인 화면을 건너뛰도록 AuthGate가 판단합니다.
      home: const AuthGate(),
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.signup: (context) => const SignupPage(),
        AppRoutes.onboarding: (context) => const ChildInfoPage(),
        AppRoutes.home: (context) => const MainShell(),
        AppRoutes.detail: (context) => const DetailPage(),
        AppRoutes.mypage: (context) => const MyPagePage(),
        AppRoutes.settings: (context) => const SettingsPage(),
      },
    );
  }
}