import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';
import 'package:flutter_project/features/detail/widgets/record_history.dart';

/// 이력 목록에 보이는 내용을 고정합니다.
///
/// DB에서 읽은 행을 사람이 읽는 문장으로 바꾸는 부분이라, 조용히 틀리면
/// 사용자가 잘못된 기록을 보게 됩니다.
void main() {
  group('FeedingRecord.fromMap', () {
    test('모유(직수)는 수량 없이 표시된다', () {
      final r = FeedingRecord.fromMap({
        'id': 'f1',
        'feeding_type': 'breast',
        'amount_ml': null,
        'fed_at': '2026-07-30T09:15:00Z',
      });

      expect(r.type, FeedingType.breast);
      expect(r.amountMl, isNull);
      expect(r.summary, '모유(직수)');
    });

    test('분유는 수량이 함께 표시된다', () {
      final r = FeedingRecord.fromMap({
        'id': 'f2',
        'feeding_type': 'formula',
        'amount_ml': 160,
        'fed_at': '2026-07-30T09:15:00Z',
      });

      expect(r.summary, '분유 · 160ml');
    });
  });

  group('DiaperRecord.fromMap', () {
    test('소변은 대변 상태 없이 표시된다', () {
      final r = DiaperRecord.fromMap({
        'id': 'd1',
        'diaper_type': 'urine',
        'stool_state': null,
        'recorded_at': '2026-07-30T08:40:00Z',
      });

      expect(r.stoolState, isNull);
      expect(r.summary, '소변');
    });

    test('대변은 상태가 함께 표시된다', () {
      final r = DiaperRecord.fromMap({
        'id': 'd2',
        'diaper_type': 'stool',
        'stool_state': 'green',
        'recorded_at': '2026-07-30T08:40:00Z',
      });

      expect(r.summary, '대변 · 녹변');
    });
  });

  group('SleepRecord.fromMap', () {
    test('수면 시간은 저장하지 않고 조회 시 계산한다', () {
      final r = SleepRecord.fromMap({
        'id': 's1',
        'sleep_type': 'night',
        'started_at': '2026-07-30T11:00:00Z',
        'ended_at': '2026-07-30T20:30:00Z',
      });

      expect(r.duration, const Duration(hours: 9, minutes: 30));
      expect(r.summary, '밤잠 · 9시간 30분');
    });

    test('ended_at이 없으면 측정 중으로 표시된다', () {
      // 소음 측정으로 만들어진 뒤 아직 중지하지 않은 행입니다.
      final r = SleepRecord.fromMap({
        'id': 's2',
        'sleep_type': 'nap',
        'started_at': '2026-07-30T04:00:00Z',
        'ended_at': null,
      });

      expect(r.duration, isNull);
      expect(r.summary, '낮잠 · 측정 중');
    });
  });

  group('TemperatureRecord.fromMap', () {
    test('증상이 없으면 체온만 표시된다', () {
      final r = TemperatureRecord.fromMap({
        'id': 't1',
        'temperature_c': 36.5,
        'measured_at': '2026-07-30T09:00:00Z',
        'temperature_symptoms': <Map<String, dynamic>>[],
      });

      expect(r.symptoms, isEmpty);
      expect(r.summary, '36.5℃');
    });

    test('중첩 select로 읽은 증상이 한글로 표시된다', () {
      final r = TemperatureRecord.fromMap({
        'id': 't2',
        'temperature_c': 38.2,
        'measured_at': '2026-07-30T09:00:00Z',
        'temperature_symptoms': [
          {'symptom': 'runny_nose'},
          {'symptom': 'cough'},
        ],
      });

      expect(r.summary, '38.2℃ · 콧물, 기침');
    });

    test('알 수 없는 증상 값은 무시하고 나머지를 보여준다', () {
      // CHECK 제약에 항목이 추가되어도 조회가 깨지지 않아야 합니다.
      final r = TemperatureRecord.fromMap({
        'id': 't3',
        'temperature_c': 37.0,
        'measured_at': '2026-07-30T09:00:00Z',
        'temperature_symptoms': [
          {'symptom': 'headache'},
          {'symptom': 'rash'},
        ],
      });

      expect(r.symptoms, [Symptom.rash]);
    });

    test('temperature_symptoms 키가 아예 없어도 깨지지 않는다', () {
      final r = TemperatureRecord.fromMap({
        'id': 't4',
        'temperature_c': 36.8,
        'measured_at': '2026-07-30T09:00:00Z',
      });

      expect(r.symptoms, isEmpty);
    });
  });

  group('formatRecordTime', () {
    final now = DateTime(2026, 7, 30, 15, 0);

    test('오늘이면 날짜를 생략한다', () {
      expect(formatRecordTime(DateTime(2026, 7, 30, 9, 5), now: now),
          '오늘 오전 9:05');
    });

    test('다른 날이면 날짜를 붙인다', () {
      expect(formatRecordTime(DateTime(2026, 7, 29, 21, 30), now: now),
          '7/29 오후 9:30');
    });

    test('자정과 정오를 12시로 표기한다', () {
      // 0시는 오전 12시, 12시는 오후 12시입니다.
      expect(formatRecordTime(DateTime(2026, 7, 30, 0, 10), now: now),
          '오늘 오전 12:10');
      expect(formatRecordTime(DateTime(2026, 7, 30, 12, 0), now: now),
          '오늘 오후 12:00');
    });
  });
}
