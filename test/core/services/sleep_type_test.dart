import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project/core/services/sleep_type.dart';

void main() {
  group('SleepType', () {
    // enum 이름이 곧 DB에 들어가는 값입니다. sleep_records.sleep_type의
    // CHECK 제약이 'night'/'nap'만 허용하므로, 이름이 바뀌면 insert가 실패합니다.
    test('enum names match the sleep_records.sleep_type CHECK values', () {
      expect(SleepType.night.name, 'night');
      expect(SleepType.nap.name, 'nap');
      expect(SleepType.values.map((e) => e.name), ['night', 'nap']);
    });

    test('parse restores a value sent through service.invoke', () {
      expect(SleepType.parse('night'), SleepType.night);
      expect(SleepType.parse('nap'), SleepType.nap);
    });

    test('parse falls back to night for missing or unknown input', () {
      expect(SleepType.parse(null), SleepType.night);
      expect(SleepType.parse(''), SleepType.night);
      expect(SleepType.parse('밤잠'), SleepType.night);
      expect(SleepType.parse('deep'), SleepType.night);
    });

    test('labels are the Korean text shown on the measurement screen', () {
      expect(SleepType.night.label, '밤잠');
      expect(SleepType.nap.label, '낮잠');
    });
  });
}
