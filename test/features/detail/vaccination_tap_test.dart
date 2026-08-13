import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **완료한 접종은 눌러도 사라지지 않습니다.**
///
/// 예전에는 목록 항목을 누르면 곧바로 DELETE가 나갔습니다. 확인 창도 없이
/// '예정'으로 돌아갔고, 되살리려고 다시 누르면 접종일이 **오늘**로 바뀌어
/// 실제로 맞은 날이 사라졌습니다. 목록 전체가 InkWell이라 스크롤 중에도
/// 눌렸습니다.
///
/// 접종 기록은 "언제 맞았더라"를 확인하려고 남기는 것입니다. 지우는 쪽이
/// 기본이면 그 목적을 잃습니다.
void main() {
  final page =
      File('lib/features/detail/vaccination_page.dart').readAsStringSync();
  final service =
      File('lib/features/detail/vaccination_service.dart').readAsStringSync();

  group('탭은 지우지 않는다', () {
    test('완료 항목을 누르면 날짜 수정이 열린다', () {
      final onTap = page.substring(
        page.indexOf('Future<void> _onTap('),
        page.indexOf('Future<void> _editVaccinatedOn('),
      );
      expect(onTap.contains('_editVaccinatedOn(status)'), isTrue);
      expect(onTap.contains('unmark'), isFalse,
          reason: '탭 경로에 삭제가 있으면 안 됩니다');
    });

    test('날짜 수정은 선택기를 연다', () {
      final edit = page.substring(page.indexOf('Future<void> _editVaccinatedOn('));
      expect(edit.contains('showDatePicker'), isTrue);
      // 미래 날짜는 고를 수 없습니다. 아직 안 맞은 날을 접종일로 둘 수 없습니다.
      expect(edit.contains('final last = DateTime.now();'), isTrue);
      expect(edit.contains('lastDate: last'), isTrue);
    });

    test('생년월일을 뒤로 고쳐도 열린다', () {
      // initialDate는 DB의 접종일, firstDate는 지금의 생년월일입니다.
      // 생년월일을 더 늦은 날로 고치면 initialDate < firstDate가 되고
      // showDatePicker가 단정에 걸려 **아무 일도 일어나지 않습니다.**
      final edit = page.substring(page.indexOf('Future<void> _editVaccinatedOn('));
      expect(edit.contains('recorded.isBefore(first)'), isTrue);
      expect(edit.contains('recorded.isAfter(last)'), isTrue);
      expect(edit.contains('initialDate: initial'), isTrue);
    });
  });

  group('지우는 길은 하나뿐이고 확인을 거친다', () {
    test('DELETE 호출부가 하나다', () {
      expect('unmarkVaccinated'.allMatches(page).length, 1,
          reason: '지우는 곳이 여럿이면 하나를 놓칩니다');
    });

    test('그 하나가 _undo 안에 있다', () {
      final undo = page.substring(
        page.indexOf('Future<void> _undo('),
        page.indexOf('Future<void> _markDone('),
      );
      expect(undo.contains('VaccinationService.unmarkVaccinated'), isTrue);
    });

    test('확인 창을 먼저 띄운다', () {
      final undo = page.substring(
        page.indexOf('Future<void> _undo('),
        page.indexOf('Future<void> _markDone('),
      );
      expect(
        undo.indexOf('confirmDestructive') <
            undo.indexOf('VaccinationService.unmarkVaccinated'),
        isTrue,
      );
      expect(undo.contains('if (!ok) return;'), isTrue);
    });

    test('길게 눌러야 닿는다', () {
      // 탭에 두면 스크롤 중에 눌립니다.
      expect(page.contains('onLongPress:'), isTrue);
      expect(page.contains('isUpdating || !isCompleted ? null : () => _undo(status)'),
          isTrue,
          reason: '완료 항목에만 있어야 합니다');
    });
  });

  group('기록이 쌓이지 않고 갱신된다', () {
    test('upsert가 아이+백신으로 충돌을 잡는다', () {
      // 날짜를 고칠 때마다 행이 새로 생기면 목록에 같은 백신이 여러 번
      // 뜹니다. schema.sql의 vaccination_unique_per_baby와 짝입니다.
      expect(service.contains("onConflict: 'baby_id,vaccine_id'"), isTrue);
    });

    test('스키마에 그 UNIQUE가 있다', () {
      final schema = File('supabase/schema.sql').readAsStringSync();
      expect(
        schema.contains(
            'constraint vaccination_unique_per_baby unique (baby_id, vaccine_id)'),
        isTrue,
      );
    });
  });
}
