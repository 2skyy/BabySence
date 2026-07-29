import 'package:audioplayers/audioplayers.dart';

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
    onStateChanged();
  }

  // 전체 정지
  Future<void> stopAll(Function onStateChanged) async {
    await _audioPlayer.stop();
    isPlaying = false;
    currentPlayingId = null;
    onStateChanged();
  }
}