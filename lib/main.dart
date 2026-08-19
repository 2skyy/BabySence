import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/notification_setup.dart';

// ★ 백엔드 파이어베이스 및 수파베이스 임포트
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/constants/supabase_config.dart';
import 'core/services/auth_redirect.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/login_page.dart';
import 'features/auth/signup_page.dart';
import 'features/shell/main_shell.dart';
import 'features/mypage/mypage_page.dart';
import 'features/onboarding/child_info_page.dart';
import 'features/settings/settings_page.dart';
import 'routes/app_routes.dart';

import 'core/services/background_auth.dart';
import 'features/detail/white_noise_service.dart' show whiteNoiseStateSignal;
import 'core/services/noise_tracker.dart';
import 'core/services/sleep_type.dart';

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
  // 권한은 _requestAppPermissions에서 따로 받으므로 여기서는 요청하지 않습니다.
  // 설정을 직접 적지 않는 이유는 [notificationInitSettings]에 적어 뒀습니다 —
  // 네 곳에 흩어져 있던 탓에 macOS 항목이 **전부** 빠져 있었습니다.
  await flutterLocalNotificationsPlugin.initialize(
    settings: notificationInitSettings(),
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
  // 여기까지 오지 않으므로, 소음을 저장하려면 이 isolate에서 다시 초기화해야
  // 합니다.
  //
  // **로그인 저장소를 공유하지 않습니다.** 예전에는 그냥 초기화해서 화면 쪽과
  // 같은 서랍을 썼는데, Supabase의 갱신 토큰은 한 번 쓰면 버려지는 티켓이라
  // 두 쪽이 같은 서랍에서 꺼내 가면 사슬이 끊깁니다. 밤새 백그라운드만
  // 갈아치우다가 아침에 화면이 옛 티켓을 내밀면 로그아웃되고, 그 뒤 조회는
  // 오류가 아니라 **빈 목록**을 돌려줘 "아이 정보가 없습니다"가 떴습니다.
  // 자세한 사정은 core/services/background_auth.dart.
  //
  // 그래서 이쪽은 스스로 갱신하지 않고(autoRefreshToken: false) 저장소도
  // 비워 둡니다(EmptyLocalStorage). 토큰은 화면이 [backgroundAuthSignal]로
  // 실어 보냅니다.
  //
  // 여기서 곧바로 기다리면 그동안 UI가 보낸 신호를 받을 리스너가 아직 없어
  // 신호가 사라집니다. 그래서 시작만 해 두고, 저장이 필요한 시점에 기다립니다.
  final Future<void> supabaseReady = () async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          localStorage: EmptyLocalStorage(),
          // 딥링크 감시는 화면 쪽만 합니다.
          detectSessionInUri: false,
        ),
      );
    } catch (e) {
      debugPrint('백그라운드 Supabase 초기화 실패(소음 저장 불가): $e');
    }
  }();

  final AudioPlayer audioPlayer = AudioPlayer();
  NoiseTracker noiseTracker = NoiseTracker();

  NoiseMeter? noiseMeter;
  StreamSubscription<NoiseReading>? noiseSubscription;

  bool isNoiseMeasuring = false;
  bool isWhiteNoisePlaying = false;

  /// 진행 중인 마무리.
  ///
  /// 중지는 `isNoiseMeasuring`을 **먼저** 내리고 마무리를 던지므로, 그 사이에
  /// 시작 신호가 오면 중복 가드를 그냥 통과합니다. 그러면 앞 세션의 finish()
  /// 밑에서 beginSession()이 집계를 지워, 어젯밤 결과가 새 세션 숫자로
  /// 만들어지고 그다음 마무리가 새 세션을 지웁니다.
  Future<void>? endingSession;

  /// 시작 신호를 처리하는 중인지. UI가 같은 신호를 되풀이해 보내므로,
  /// 처리 중에 들어온 신호를 걸러야 수면 기록이 겹치지 않습니다.
  bool isStartingNoise = false;

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

  /// 지금 측정 중인지를 UI에 알립니다. UI는 이 응답을 받고서야 화면을 바꿉니다.
  void reportNoiseState() {
    service.invoke('noise_state', {'measuring': isNoiseMeasuring});
  }

  /// 측정을 닫고 **집계를 UI에 실어 보냅니다.**
  ///
  /// 예전에는 id만 보내서, UI가 고정 2초를 기다렸다가 서버에서 통계를 다시
  /// 읽었습니다. 느린 망에서는 그 안에 저장이 안 끝나 "저장하지 못했습니다"가
  /// 떴습니다 — 조금만 더 기다리면 됐을 때가 있었습니다. 이제 숫자를 그대로
  /// 넘기므로 UI는 기다릴 것도 다시 읽을 것도 없습니다.
  ///
  /// 함수로 뺀 이유는 **끄는 길이 둘이기 때문**입니다. 소음만 멈추는 길과
  /// 서비스를 통째로 끄는 길. 예전에는 뒤쪽이 finish()만 부르고 이 알림을
  /// 보내지 않아, '완전히 끄기'로 끝낸 밤은 결과 화면을 볼 수 없었습니다.
  /// **Future를 돌려주는 이유**: 서비스를 끄는 길에서는 이걸 기다려야 합니다.
  /// 기다리지 않고 `stopSelf()`를 부르면 마지막 저장이 끝나기 전에 isolate가
  /// 죽어 밤 전체가 사라집니다.
  Future<void> endNoiseSession() async {
    // **id를 finish() 뒤에 읽습니다.** 앞에서 읽으면, 행이 마지막 순간에야
    // 만들어진 밤(시작할 때 망이 없었거나 아주 짧게 잰 경우) id가 null인 채로
    // 나갑니다. 그러면 저장은 멀쩡히 됐는데 화면은 "저장하지 못했습니다"를
    // 띄우고 판정을 버립니다.
    final result = await noiseTracker.finish();

    service.invoke('noise_session_ended', {
      'sleepRecordId': result.recordId,
      'saved': result.saved,
      if (result.stats != null) ...result.stats!.toMap(),
    });
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

          // 3. 평활된 값은 평균에, **평활 전 값은 순간 최댓값**에 씁니다.
          //    화면이 "가장 컸던 소리는 …dB"라고 말하는 값은 뒤쪽입니다.
          //    평활된 값에서 세면 배경 40dB에 90dB가 한 번 들어와도
          //    45.25dB까지만 올라가, 아이를 깨운 그 소리를 놓칩니다.
          noiseTracker.onNoiseLevelChanged(smoothedDb, peak: adjustedDb);
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
          noiseSubscription?.cancel();
          noiseSubscription = null;
          noiseMeter = null;
          isNoiseMeasuring = false;
          updateNotification();

          // **여기서 끝맺습니다.**
          //
          // 예전에는 상태만 내리고 "사용자가 중지를 누르면 집계가 나옵니다"
          // 라고 적어 뒀는데, 그때 화면 버튼은 이미 '측정 시작'으로 돌아가
          // 있습니다. 누를 수 있는 중지 버튼이 없습니다. 그 상태에서 시작을
          // 누르면 beginSession()이 집계를 지워, 지금까지 잰 것이 통째로
          // 사라지고 sleep_records 행은 ended_at 없이 남아 기록 탭에 영영
          // '측정 중'으로 보입니다.
          //
          // 화면이 없더라도 닫는 편이 낫습니다 — 집계를 받을 사람이 없어도
          // 수면 기록은 제대로 끝나고, 다음 측정이 깨끗한 상태에서 시작합니다.
          endingSession = endNoiseSession();
          reportNoiseState();
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

    // 던져두지 않고 붙잡아 둡니다. 다음 시작이 이걸 기다립니다.
    endingSession = endNoiseSession();
  }

  // --- UI 신호(이벤트) 리스너 설정 ---


  service.on('startNoiseOnly').listen((event) async {
    // 서비스가 준비되기 전에 온 신호는 사라지므로 UI가 같은 신호를 되풀이해
    // 보냅니다. 두 번째부터는 무시하고, 이미 켜져 있다고만 알려줍니다.
    if (isNoiseMeasuring || isStartingNoise) {
      reportNoiseState();
      return;
    }

    isStartingNoise = true;
    try {
      // 저장하려면 이 isolate의 Supabase가 준비돼 있어야 합니다.
      await supabaseReady;

      // 앞 세션의 마무리가 끝난 뒤에 시작합니다. 안 그러면 beginSession()이
      // 아직 도는 finish() 밑에서 집계를 지웁니다. NoiseTracker의 저장 상한
      // (8초)이 이 대기의 상한이기도 합니다.
      await endingSession;
      endingSession = null;

      // UI에서 고른 밤잠/낮잠 값을 받습니다. 없으면 밤잠으로 봅니다.
      noiseTracker.beginSession(SleepType.parse(event?['sleepType'] as String?));
      startNoiseMeasurement();
    } finally {
      isStartingNoise = false;
    }

    // 마이크를 열지 못했으면 measuring이 false로 나갑니다. UI가 그걸 보고
    // 시작에 실패했음을 알립니다.
    reportNoiseState();
  });

  // 화면이 넘겨주는 로그인 정보. 저장소를 비워 뒀으므로 이게 없으면
  // 백그라운드는 로그인하지 않은 상태입니다.
  service.on(backgroundAuthSignal).listen((event) async {
    final encoded = event?['session'] as String?;
    if (encoded == null) return;
    try {
      await supabaseReady;
      // recoverSession은 만료 전이라면 **갱신을 하지 않습니다.** 화면이 쥔
      // 티켓 사슬을 건드리지 않고 메모리에만 세션을 놓습니다.
      await Supabase.instance.client.auth.recoverSession(encoded);
    } catch (e) {
      debugPrint('백그라운드 로그인 정보를 적용하지 못했습니다: $e');
    }
  });

  service.on('stopNoiseOnly').listen((event) {
    stopNoiseMeasurement();
    reportNoiseState();
  });

  // 화면에 들어왔을 때 UI가 현재 상태를 물어봅니다. 서비스가 켜져 있어도
  // 백색소음만 재생 중일 수 있어, 켜짐 여부만으로는 알 수 없습니다.
  service.on('queryNoiseState').listen((event) {
    reportNoiseState();
  });

  // 앱이 죽은 뒤 서비스만 되살아나면 측정 중이 아닌 상태로 다시 시작합니다.
  // 화면이 묻기 전에 먼저 알려, '측정 중지'로 잘못 보이는 것을 막습니다.
  reportNoiseState();

  // 백색소음은 **UI isolate가 냅니다.** 이 신호는 재생을 시키지 않고
  // 전경 알림 문구만 맞춥니다 — 예전에는 소리가 울리는 동안에도 알림이
  // '대기 중입니다'라고 적혀 있었습니다.
  //
  // 아래 startWhiteNoiseOnly/stopWhiteNoiseOnly는 백그라운드가 직접 재생하는
  // 경로인데 지금 아무도 부르지 않습니다. 부르면 같은 소리가 두 번 납니다.
  service.on(whiteNoiseStateSignal).listen((event) {
    isWhiteNoisePlaying = event?['playing'] == true;
    updateNotification();
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

      // **finish()만 부르면 안 됩니다.** 예전에는 그랬고, 그래서 '완전히
      // 끄기'로 끝낸 밤은 UI가 끝난 줄 모른 채 결과 화면이 열리지 않았습니다.
      // 집계가 메모리에 있는 지금은 더 나빠집니다 — 그 밤이 통째로
      // 사라집니다.
      await endNoiseSession();

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// 앱 전체가 하나를 공유합니다. 설정 화면은 [ThemeScope]로 찾습니다.
  final _theme = ThemeController();

  /// 로그인이 풀리면 로그인 화면으로 보냅니다. 사정은 [AuthRedirect]에.
  final _authRedirect = AuthRedirect();

  /// **목록을 여기 붙들어 둡니다.** 빌드마다 새로 만들면 테마를 바꿀 때마다
  /// Navigator가 관찰자를 떼었다 다시 답니다(`didUpdateWidget`이 목록을
  /// 동일성으로 비교합니다). 동작은 같지만 할 이유가 없는 일입니다.
  late final List<NavigatorObserver> _navigatorObservers = [_authRedirect];

  @override
  void initState() {
    super.initState();
    // 저장된 설정을 읽습니다. 읽는 동안은 기본값(밝음)으로 보입니다.
    _theme.load();

    _authRedirect.listenTo(Supabase.instance.client.auth.onAuthStateChange);
  }

  @override
  void dispose() {
    _authRedirect.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => MaterialApp(
          navigatorObservers: _navigatorObservers,
          debugShowCheckedModeBanner: false,
          title: 'BabySence',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _theme.mode,
          // 시간·날짜 선택기가 한국어로 뜨게 합니다.
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('ko'), Locale('en')],
          // 저장된 세션이 있으면 로그인 화면을 건너뛰도록 AuthGate가 판단합니다.
          home: const AuthGate(),
          routes: {
            AppRoutes.login: (context) => const LoginPage(),
            AppRoutes.signup: (context) => const SignupPage(),
            AppRoutes.onboarding: (context) => const ChildInfoPage(),
            AppRoutes.home: (context) => const MainShell(),
            AppRoutes.mypage: (context) => const MyPagePage(),
            AppRoutes.settings: (context) => const SettingsPage(),
          },
        ),
      ),
    );
  }
}