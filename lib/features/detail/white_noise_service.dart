import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

/// 백색소음 상태를 백그라운드에 알리는 신호.
///
/// **재생을 시키는 것이 아닙니다.** 소리는 이 서비스(UI isolate)가 냅니다.
/// 백그라운드에도 재생 경로가 있지만 아무도 부르지 않으며, 부르면 같은
/// 소리가 두 번 납니다.
///
/// 이 신호는 전경 알림 문구만 맞춥니다. 예전에는 백색소음이 울리는 동안에도
/// 알림이 '대기 중입니다'라고 적혀 있었습니다.
const String whiteNoiseStateSignal = 'white_noise_state';

class WhiteNoiseService {
  // 앱 전역에서 단 하나만 존재하는 싱글톤 인스턴스
  static final WhiteNoiseService _instance = WhiteNoiseService._internal();
  factory WhiteNoiseService() => _instance;
  WhiteNoiseService._internal() {
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? currentPlayingId;
  bool isPlaying = false;

  // 소리 재생 / 일시정지 토글
  Future<void> togglePlay({
    required String id,
    required String assetPath,
    required Function onStateChanged,
  }) async {
    if (currentPlayingId == id) {
      if (isPlaying) {
        await _audioPlayer.pause();
        isPlaying = false;
      } else {
        await _audioPlayer.resume();
        isPlaying = true;
      }
    } else {
      currentPlayingId = id;
      isPlaying = true;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    }
    _report();
    onStateChanged();
  }

  // 전체 정지
  Future<void> stopAll(Function onStateChanged) async {
    await _audioPlayer.stop();
    isPlaying = false;
    currentPlayingId = null;
    _report();
    onStateChanged();
  }

  /// 지금 상태를 백그라운드에 알립니다. 서비스가 꺼져 있으면 아무 일도
  /// 일어나지 않습니다.
  void _report() {
    FlutterBackgroundService()
        .invoke(whiteNoiseStateSignal, {'playing': isPlaying});
  }
}