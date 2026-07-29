/// Supabase 연결 정보.
///
/// 실제 값은 소스가 아니라 env.json에서 주입됩니다.
///
///   flutter run --dart-define-from-file=env.json
///
/// env.json은 .gitignore에 등록되어 있으므로, 저장소를 처음 받으면
/// env.example.json을 복사해 값을 채워 넣으세요.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
