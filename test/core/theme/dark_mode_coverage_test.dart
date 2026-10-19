import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 다크 모드가 **화면까지** 닿는지 소스를 훑어 확인합니다.
///
/// 팔레트만 검사하던 `dark_mode_golden_test.dart`는 이 문제를 못 잡았습니다.
/// 팔레트는 멀쩡했지만 화면 12개가 자기 색 상수를 따로 들고 있어서, 스위치를
/// 켜도 그 화면들은 밝은 채로 남아 있었습니다.
///
/// 그래서 여기서는 위젯 대신 **파일 내용**을 봅니다. 화면 26개를 다크 모드로
/// 띄우려면 Supabase가 필요해 위젯 테스트로는 감당이 안 됩니다.
void main() {
  /// `AppPalette.light`에 이미 있는 값들. 화면이 이 값을 직접 쓰면 테마를
  /// 바꿔도 그 자리만 밝은 채로 남습니다.
  const lightPaletteLiterals = {
    '0xFFF8FAFC': 'background',
    '0xFFF9F9F9': 'background',
    '0xFFF8F9FB': 'background',
    '0xFFF8F9FA': 'background',
    '0xFF111827': 'textPrimary',
    '0xFF1F2937': 'textPrimary',
    '0xFF1A1C1C': 'textPrimary',
    '0xFF6B7280': 'textSecondary',
    '0xFF555F6A': 'textSecondary',
    '0xFFE5E7EB': 'border',
  };

  List<File> dartFilesIn(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// 검사 대상은 화면과 공용 위젯입니다.
  ///
  /// 처음에는 `lib/features`만 봤는데, 그 사이 `CommonAppBar`가 흰 바탕을
  /// 그대로 들고 있었습니다. 화면 6개가 그걸 쓰고 있었는데도 통과했습니다.
  ///
  /// 팔레트를 정의하는 두 파일은 당연히 색 값을 갖고 있으므로 뺍니다.
  final themedSources = [
    ...dartFilesIn('lib/features'),
    ...dartFilesIn('lib/core'),
  ].where((f) =>
      !f.path.endsWith('app_colors.dart') &&
      !f.path.endsWith('app_theme.dart')).toList();

  test('화면이 팔레트 색을 직접 적어 두지 않는다', () {
    final offenders = <String>[];

    for (final file in themedSources) {
      final source = file.readAsStringSync();
      lightPaletteLiterals.forEach((literal, slot) {
        if (source.contains(literal)) {
          offenders.add('${file.path}: $literal → context.colors.$slot');
        }
      });
    }

    expect(offenders, isEmpty,
        reason: '팔레트에 이미 있는 색입니다. 직접 적으면 다크 모드에서 안 바뀝니다.\n'
            '${offenders.join('\n')}');
  });

  test('회색·검정 글씨를 박아 두지 않는다', () {
    // 처음 훑을 때 Colors.white와 색 코드만 봐서 이걸 통째로 놓쳤습니다.
    // 그 결과 아이 이름·몸무게 입력 글씨가 다크 모드에서 안 보였습니다.
    //
    // 그림자(`Colors.black.withValues`)와 애플 로그인 버튼은 두 테마에서
    // 모두 검정이라야 하므로 대상이 아닙니다.
    final banned = RegExp(
      r'Colors\.(grey\[(100|200|300|350|400|500|600|700)\]|grey\b(?!\[)'
      r'|black87|black54|black45)',
    );
    final offenders = <String>[];

    for (final file in themedSources) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }

    expect(offenders, isEmpty,
        reason: '어두운 배경에서 묻힙니다. context.colors의 textSecondary나 border를 쓰세요.\n'
            '${offenders.join('\n')}');
  });

  test('화면 배경으로 흰색을 박아 두지 않는다', () {
    // 색깔 버튼 위의 흰 글씨는 두 테마에서 모두 흰색이라야 하므로 대상이
    // 아닙니다. 여기서 막는 것은 화면·앱바의 바탕입니다.
    //
    // 브랜드 색처럼 정말 흰색이어야 하는 자리는 바로 위 줄에 `테마 예외:`와
    // 이유를 적어 두면 넘어갑니다. 조용히 빠져나가지 못하게 하려는 것입니다.
    final offenders = <String>[];

    for (final file in themedSources) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'backgroundColor:\s*Colors\.white').hasMatch(lines[i])) {
          continue;
        }
        final exempted = lines
            .sublist((i - 3).clamp(0, i), i)
            .any((l) => l.contains('테마 예외:'));
        if (!exempted) offenders.add('${file.path}:${i + 1}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'Scaffold·AppBar 바탕은 context.colors.background나 surface여야 합니다.\n'
            '${offenders.join('\n')}');
  });

  test('모든 화면이 테마 색을 쓴다', () {
    // 한 곳도 안 쓴다면 그 화면은 통째로 밝은 채로 남아 있다는 뜻입니다.
    final untouched = <String>[];

    for (final file in themedSources) {
      if (!file.path.endsWith('_page.dart')) continue;
      if (!file.readAsStringSync().contains('context.colors')) {
        untouched.add(file.path);
      }
    }

    expect(untouched, isEmpty,
        reason: '이 화면들은 다크 모드에서 밝은 채로 남습니다.\n${untouched.join('\n')}');
  });
}
