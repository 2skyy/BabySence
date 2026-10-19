import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/vaccination_service.dart';
import 'package:flutter_project/features/vaccination_reminder/vaccination_reminder_service.dart';
import 'package:flutter_project/features/vaccination_reminder/vaccination_reminder_settings.dart';

void main() {
  group('알림을 울릴 시각', () {
    test('예정일에서 며칠 당긴 날 오전 9시다', () {
      // 예정일은 날짜만 있는 값(자정)이라 그대로 쓰면 한밤중에 울립니다.
      expect(
        VaccinationReminderService.notifyAtFor(DateTime(2026, 8, 20), 3),
        DateTime(2026, 8, 17, 9),
      );
    });

    test('당일이면 예정일 아침이다', () {
      expect(
        VaccinationReminderService.notifyAtFor(DateTime(2026, 8, 20), 0),
        DateTime(2026, 8, 20, 9),
      );
    });

    test('달을 넘어도 말일을 맞게 짚는다', () {
      // 3월 1일에서 사흘 전은 2월 26일입니다. 날짜를 그대로 빼면 3월 -2일이
      // 되는데, 생성자가 그것을 2월로 정규화합니다.
      expect(
        VaccinationReminderService.notifyAtFor(DateTime(2026, 3, 1), 3),
        DateTime(2026, 2, 26, 9),
      );
      expect(
        VaccinationReminderService.notifyAtFor(DateTime(2026, 5, 2), 7),
        DateTime(2026, 4, 25, 9),
      );
    });

    test('해를 넘어도 맞다', () {
      expect(
        VaccinationReminderService.notifyAtFor(DateTime(2026, 1, 2), 7),
        DateTime(2025, 12, 26, 9),
      );
    });

    test('윤년 2월 29일을 안다', () {
      // 2028년은 윤년입니다. 3월 1일의 하루 전은 2월 29일입니다.
      expect(
        VaccinationReminderService.notifyAtFor(DateTime(2028, 3, 1), 1),
        DateTime(2028, 2, 29, 9),
      );
    });

    test('고를 수 있는 값 넷이 모두 그만큼 앞선 날 아침이다', () {
      // 당일(0)은 예정일 오전 9시라 자정보다는 뒤입니다. 시각이 아니라
      // **날짜**로 견줍니다.
      final due = DateTime(2026, 8, 20);
      for (final days in VaccinationReminderSettings.selectableDaysBefore) {
        final at = VaccinationReminderService.notifyAtFor(due, days);
        expect(DateTime(at.year, at.month, at.day),
            DateTime(due.year, due.month, due.day - days),
            reason: '$days일 전이 어긋납니다');
        expect(at.hour, 9);
      }
    });

    test('날짜를 뺄 때 Duration을 쓰지 않는다', () {
      // 이것은 글자로 봅니다. 진짜 증상은 **서머타임이 있는 시간대에서만**
      // 드러나는데, 테스트는 이 기기의 시간대로 돌아 한국에서는 두 방식이
      // 같은 답을 냅니다 — 위 단언들은 되돌려 놔도 전부 통과합니다.
      //
      // Duration은 절대 시간이라 자정에서 24시간을 빼면 서머타임 전환일에는
      // 전날 23시가 되고, 거기서 날짜를 꺼내면 하루가 통째로 밀립니다.
      // (America/New_York에서 확인: 3월 9일의 하루 전이 3월 7일로 나왔습니다.)
      final source = File(
        'lib/features/vaccination_reminder/vaccination_reminder_service.dart',
      ).readAsStringSync();

      final start = source.indexOf('static DateTime notifyAtFor(');
      expect(start, isNonNegative, reason: 'notifyAtFor를 찾지 못했습니다');
      final body = source.substring(start, source.indexOf(';', start));

      expect(body.contains('Duration('), isFalse,
          reason: '달력 날짜로 빼야 합니다: DateTime(y, m, d - n)');
      expect(body.contains('scheduledOn.day - daysBefore'), isTrue);
    });
  });

  group('알림 설정', () {
    test('처음에는 꺼져 있다', () {
      // 켠 적 없는 알림이 갑자기 울리면 안 됩니다.
      const settings = VaccinationReminderSettings();
      expect(settings.notify, isFalse);
      expect(VaccinationReminderSettings.defaultNotify, isFalse);
    });

    test('기본값이 고를 수 있는 값 안에 있다', () {
      // 목록에 없는 기본값이면 설정 화면에서 아무것도 안 골라진 채로 뜹니다.
      expect(
        VaccinationReminderSettings.selectableDaysBefore,
        contains(VaccinationReminderSettings.defaultDaysBefore),
      );
    });

    test('한 쪽만 바꿔도 나머지가 남는다', () {
      const settings = VaccinationReminderSettings(notify: true, daysBefore: 7);
      expect(settings.copyWith(daysBefore: 1),
          const VaccinationReminderSettings(notify: true, daysBefore: 1));
      expect(settings.copyWith(notify: false),
          const VaccinationReminderSettings(notify: false, daysBefore: 7));
    });

    test('당일은 이름으로 부른다', () {
      expect(formatDaysBefore(0), '당일');
      expect(formatDaysBefore(3), '3일 전');
    });
  });

  group('알림 제목', () {
    test('이름을 알면 부르고, 모르면 지어내지 않는다', () {
      // 수유 알림과 같은 규칙입니다. 두 알림이 다르게 말하면 같은 앱에서
      // 온 것으로 읽히지 않습니다.
      expect(VaccinationReminderService.notificationTitle('지호'),
          '지호 예방접종 예정일이 다가와요');
      for (final blank in [null, '', '  ']) {
        expect(VaccinationReminderService.notificationTitle(blank),
            '예방접종 예정일이 다가와요');
      }
    });
  });

  group('알림 본문', () {
    VaccinationStatus statusFor(DateTime on) => VaccinationStatus(
          vaccine: const Vaccine(
            id: 7,
            code: 'DTaP_1',
            name: 'DTaP 1차',
            recommendedAgeLabel: '생후 2개월',
            recommendedAgeMonths: 2,
            doseNumber: 1,
          ),
          scheduledOn: on,
        );

    test('며칠 전이면 날짜와 남은 날을 함께 적는다', () {
      expect(
        VaccinationReminderService.notificationBody(
            statusFor(DateTime(2026, 8, 20)), 3),
        'DTaP 1차 접종 예정일이 8월 20일(3일 뒤)이에요.',
      );
    });

    test('당일이면 날짜 대신 오늘이라 부른다', () {
      // '8월 20일(0일 뒤)'은 사람이 쓰는 말이 아닙니다.
      expect(
        VaccinationReminderService.notificationBody(
            statusFor(DateTime(2026, 8, 20)), 0),
        'DTaP 1차 접종 예정일이 오늘이에요.',
      );
    });

    test('맞아야 한다고 말하지 않는다', () {
      // 접종 가능 여부는 진찰로 가리는 것이라 앱이 계산할 수 없습니다.
      // 표준 일정을 옮겨 적기만 합니다.
      final body = VaccinationReminderService.notificationBody(
          statusFor(DateTime(2026, 8, 20)), 1);
      for (final word in ['맞아야', '접종하세요', '필요합니다', '해야']) {
        expect(body.contains(word), isFalse, reason: '"$word"가 들어 있습니다: $body');
      }
    });
  });

  group('이름이 알림까지 흘러가는가', () {
    // 제목·본문 함수는 위에서 봤습니다. 정작 이번에 비어 있던 것은 **배선**
    // 입니다 — 함수에 상수를 넘겨도 위 단언은 전부 초록입니다.
    String read(String path) => File(path).readAsStringSync();

    test('예약이 받은 이름을 제목 함수에 넘긴다', () {
      final source = read(
          'lib/features/vaccination_reminder/vaccination_reminder_service.dart');
      expect(source.contains('title: notificationTitle(babyName),'), isTrue,
          reason: '제목에 진짜 이름이 아니라 다른 값을 넘기고 있습니다');
      expect(
          source.contains(
              '_scheduleOne(status, notifyAt, settings.daysBefore, babyName)'),
          isTrue,
          reason: 'reschedule이 받은 이름을 _scheduleOne까지 넘겨야 합니다');
    });

    test('화면이 아이 이름을 넘긴다', () {
      expect(
        read('lib/features/detail/vaccination_page.dart')
            .contains('babyName: _baby?.name'),
        isTrue,
        reason: '예방접종 화면이 이름 없이 예약하고 있습니다',
      );
    });
  });
}
