import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 마이페이지의 아이 정보 수정에서 키·몸무게를 남길 수 있어야 합니다.
///
/// 다만 이 둘은 `babies`의 칸이 아닙니다. 날짜와 함께 남는 성장 기록이라,
/// **언제 잰 것인지**가 없으면 곡선을 그릴 수 없습니다. 그래서 여기서 적은
/// 값은 오늘 기록이 되고, 화면에도 그렇게 적혀 있어야 합니다.
///
/// 이 화면은 static 서비스를 직접 부르는 구조라 위젯 테스트로 돌릴 수
/// 없습니다. 지켜야 할 성질만 글자로 고정합니다.
void main() {
  final page =
      File('lib/features/mypage/baby_edit_page.dart').readAsStringSync();

  group('키·몸무게를 남길 수 있다', () {
    test('입력 칸이 있다', () {
      expect(page.contains("labelText: '키 (cm)'"), isTrue);
      expect(page.contains("labelText: '몸무게 (kg)'"), isTrue);
    });

    test('babies가 아니라 성장 기록으로 남긴다', () {
      // babies에는 이 컬럼이 없습니다. 넣으면 날짜가 사라지고, 같은 값을
      // 두 곳에 적게 됩니다.
      expect(page.contains('GrowthRecordService.saveRecord'), isTrue);
      final update = page.substring(page.indexOf('BabyService.update('),
          page.indexOf('GrowthRecordService.saveRecord'));
      expect(update.contains('heightCm'), isFalse);
      expect(update.contains('weightKg'), isFalse);
    });

    test('오늘 날짜로 남긴다', () {
      expect(page.contains('date: DateTime(now.year, now.month, now.day)'),
          isTrue);
    });

    test('입력 범위가 DB CHECK과 같다', () {
      // growth_records: height_cm 20~150, weight_kg 0.5~40
      expect(page.contains('height < 20 || height > 150'), isTrue);
      expect(page.contains('weight < 0.5 || weight > 40'), isTrue);
    });
  });

  group('실수로 덮어쓰지 않는다', () {
    test('지금 값을 칸에 미리 채우지 않는다', () {
      // 채워 두면 저장 버튼을 누르는 것만으로 지난달에 잰 값이 오늘 값으로
      // 다시 남습니다. 성장 곡선이 평평해집니다.
      expect(page.contains('_height = TextEditingController()'), isTrue);
      expect(page.contains('_weight = TextEditingController()'), isTrue);
      expect(page.contains('TextEditingController(text: widget.baby'), isTrue,
          reason: '이름만 미리 채웁니다');
    });

    test('마지막으로 잰 날짜를 보여준다', () {
      // "지금 값"이 언제 것인지 모르면 오늘 값으로 착각합니다.
      expect(page.contains('에 잰 값'), isTrue);
    });

    test('여기서 적은 값이 오늘 것임을 밝힌다', () {
      expect(page.contains('오늘 잰 것으로 남습니다'), isTrue);
      expect(page.contains("hintText: '오늘 잰 값'"), isTrue);
    });
  });

  group('실패를 삼키지 않는다', () {
    test('지난 기록을 못 읽은 것과 없는 것을 구별한다', () {
      // 못 읽었는데 "아직 남긴 기록이 없어요"를 보여주면, 사용자는 처음
      // 재는 줄 알고 적습니다.
      expect(page.contains('_growthFailed'), isTrue);
      expect(page.contains('지난 기록을 불러오지 못했어요'), isTrue);
      expect(page.contains('아직 남긴 기록이 없어요'), isTrue);
    });

    test('아이 정보는 저장됐다는 것을 말한다', () {
      // 통째로 실패했다고 하면 다시 눌러 이름을 또 저장하게 됩니다.
      expect(page.contains('아이 정보는 저장했지만 키·몸무게는 남기지 못했습니다'),
          isTrue);
    });
  });
}
