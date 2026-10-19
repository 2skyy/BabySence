import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
// 시간을 '7시간 30분'으로 쓰는 것은 분석 탭이 이미 갖고 있습니다. 화면 글씨와
// 낭독 라벨이 같은 함수를 써야 같은 잠을 같은 말로 부릅니다.
import '../../core/services/duration_text.dart';
import 'record_period.dart';

/// 하루를 24시간 원으로 그립니다 — 방학 생활계획표와 같은 모양입니다.
///
/// 0시가 12시 방향이고 시계방향으로 돕니다. 벽시계와 같은 방향이라 "새벽에
/// 깼다"가 왼쪽 위에 오는 것을 따로 배우지 않아도 됩니다.
///
/// 색은 전부 생성자로 받습니다. [CustomPainter]에는 `BuildContext`가 없어
/// `context.colors`를 읽을 수 없고, 팔레트 값을 안에 적어 두면 다크 모드에서
/// 이 원만 밝은 채로 남습니다.

/// 0시를 12시 방향에 두기 위한 보정. 캔버스의 0라디안은 3시 방향입니다.
const double _zeroHour = -math.pi / 2;

double _angleOf(double hour) => _zeroHour + (hour / 24) * 2 * math.pi;

/// 선택한 하루의 큰 원. 시각 눈금과 수유·배변 점까지 그립니다.
class DayRing extends StatelessWidget {
  final DayPattern pattern;

  /// 원 전체가 차지하는 정사각형의 한 변.
  final double size;

  const DayRing({super.key, required this.pattern, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // **값은 옆 범례가 말합니다.** 여기서도 같은 값을 적으면 낭독기가
      // '수면 11시간, 수유 9회…'를 두 번 읽습니다. 그림에는 그림이라는
      // 사실과 무엇이 담겼는지만 남깁니다.
      label: '24시간 원. 수면·수유·배변을 하루 시각 위에 그렸습니다. '
          '${pattern.hasOngoingSleep ? '측정 중인 잠이 있습니다. ' : ''}'
          '자세한 값은 옆에 있습니다.',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            arcs: pattern.sleepArcs,
            dots: pattern.dots,
            trackColor: context.colors.border,
            sleepColor: context.colors.sleepArc,
            feedingColor: context.colors.feedingDot,
            diaperColor: context.colors.diaperDot,
            labelColor: context.colors.textSecondary,
            ringWidth: 14,
            showHourLabels: true,
          ),
        ),
      ),
    );
  }
}

/// 주간 스트립에 서는 작은 원. 수면 호와 날짜만 있습니다.
///
/// 여기에 점까지 찍으면 지름 40 안에서 서로 겹쳐 얼룩이 됩니다. 작은 원은
/// "언제 잤는가"만 말하고, 나머지는 아래 큰 원이 맡습니다.
class DayRingChip extends StatelessWidget {
  final DayPattern pattern;
  final bool selected;
  final bool isToday;
  final double size;
  final VoidCallback onTap;

  /// 원 위에 요일을 적을지. 달 달력은 머리글에 요일이 한 줄로 이미 있어
  /// 칸마다 되풀이하면 서른 번 읽히는 글자가 됩니다.
  final bool showWeekday;

  const DayRingChip({
    super.key,
    required this.pattern,
    required this.selected,
    required this.isToday,
    required this.onTap,
    this.size = 38,
    this.showWeekday = true,
  });

  @override
  Widget build(BuildContext context) {

    // 선택한 날은 글씨가 아니라 **바탕**으로 알립니다. 색만 바꾸면 다크 모드나
    // 색각 이상에서 어느 날이 선택됐는지 보이지 않습니다.
    final numberColor = selected
        ? Colors.white
        : (isToday ? AppColors.primary : context.colors.textPrimary);

    // 선택은 바탕색으로, 기록 유무는 4dp 점으로만 알립니다 — 둘 다 그림이라
    // 낭독기에는 잡히지 않아, 날짜 숫자만 서른한 번 읽히고 어느 날이 골라져
    // 있는지도 어느 날에 기록이 있는지도 알 수 없습니다. 말로도 알립니다.
    final weekday = showWeekday ? '${weekdayLabel(pattern.day)}요일, ' : '';

    return Semantics(
      button: true,
      selected: selected,
      // **이 칩이 그리는 것은 수면 호뿐입니다**(64~67행). 그런데 라벨에
      // 수면이 없어, 밤새 자고 수유·배변을 안 남긴 날이 낭독기에는
      // '수유 0회, 배변 0회'로만 읽혀 **기록 없는 날과 똑같아졌습니다.**
      // 큰 원과 같은 함수로 적어 두 원이 같은 말을 하게 합니다.
      //
      // '오늘'도 색으로만 알리고 있어 함께 넣습니다.
      label: '${isToday ? '오늘, ' : ''}'
          '$weekday${pattern.day.month}월 ${pattern.day.day}일, '
          '${pattern.sleepArcs.isEmpty ? '수면 기록 없음' : '수면 ${formatDuration(pattern.sleepTotal)}'}, '
          '수유 ${pattern.feedingCount}회, 배변 ${pattern.diaperCount}회.',
      // 안쪽 숫자·요일 글씨는 라벨이 이미 말했습니다. 함께 읽으면 같은 날이
      // 두 번 불립니다. 대신 누르는 동작은 여기서 직접 답합니다.
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showWeekday) ...[
                Text(
                  weekdayLabel(pattern.day),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday
                        ? AppColors.primary
                        : context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _RingPainter(
                    arcs: pattern.sleepArcs,
                    dots: const [],
                    trackColor: context.colors.border,
                    sleepColor: context.colors.sleepArc,
                    feedingColor: context.colors.feedingDot,
                    diaperColor: context.colors.diaperDot,
                    labelColor: context.colors.textSecondary,
                    ringWidth: 4,
                    showHourLabels: false,
                    fillColor: selected ? AppColors.primary : null,
                  ),
                  child: Center(
                    child: Text(
                      '${pattern.day.day}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected || isToday ? FontWeight.w700 : FontWeight.w400,
                        color: numberColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 그 날 무엇을 남겼는지. 원에 점을 못 찍는 대신입니다.
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (pattern.feedingCount > 0)
                      _MiniDot(color: context.colors.feedingDot),
                    if (pattern.diaperCount > 0)
                      _MiniDot(color: context.colors.diaperDot),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  final Color color;

  const _MiniDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 4,
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _RingPainter extends CustomPainter {
  final List<SleepArc> arcs;
  final List<DayDot> dots;
  final Color trackColor;
  final Color sleepColor;
  final Color feedingColor;
  final Color diaperColor;
  final Color labelColor;
  final double ringWidth;
  final bool showHourLabels;

  /// 선택된 날의 바탕. null이면 칠하지 않습니다.
  final Color? fillColor;

  const _RingPainter({
    required this.arcs,
    required this.dots,
    required this.trackColor,
    required this.sleepColor,
    required this.feedingColor,
    required this.diaperColor,
    required this.labelColor,
    required this.ringWidth,
    required this.showHourLabels,
    this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 원 바깥에는 배변 점이 앉을 자리를 남깁니다.
    final outerPad = dots.isEmpty ? ringWidth / 2 : ringWidth / 2 + 8;
    final radius = size.width / 2 - outerPad;
    if (radius <= 0) return;

    if (fillColor != null) {
      canvas.drawCircle(
        center,
        radius - ringWidth / 2,
        Paint()..color = fillColor!,
      );
    }

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final sleep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      // 이어진 잠이 조각조각으로 보이지 않게 끝을 둥글리지 **않습니다**.
      // 둥근 끝은 양쪽으로 반지름만큼 번져 20분짜리 잠을 40분으로 보이게 합니다.
      ..strokeCap = StrokeCap.butt
      ..color = sleepColor;

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final arc in arcs) {
      canvas.drawArc(
        rect,
        _angleOf(arc.startHour),
        (arc.hours / 24) * 2 * math.pi,
        false,
        sleep,
      );
    }

    // 수유는 안쪽, 배변은 바깥쪽에 찍습니다. 같은 반지름에 두면 새벽 수유와
    // 그 직후 기저귀가 한 점으로 겹칩니다.
    for (final dot in dots) {
      final isFeeding = dot.kind == DotKind.feeding;
      final r = isFeeding
          ? radius - ringWidth / 2 - 5
          : radius + ringWidth / 2 + 5;
      final angle = _angleOf(dot.hour);
      canvas.drawCircle(
        center + Offset(math.cos(angle) * r, math.sin(angle) * r),
        2.6,
        Paint()..color = isFeeding ? feedingColor : diaperColor,
      );
    }

    if (!showHourLabels) return;

    // 눈금은 원 **안쪽**에 둡니다. 바깥에 두면 위젯 정사각형을 넘어가 잘립니다.
    final labelRadius = radius - ringWidth / 2 - 13;
    if (labelRadius <= 0) return;

    for (final hour in const [0, 6, 12, 18]) {
      final painter = TextPainter(
        text: TextSpan(
          text: '$hour',
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final angle = _angleOf(hour.toDouble());
      final at = center +
          Offset(math.cos(angle) * labelRadius, math.sin(angle) * labelRadius);
      painter.paint(
        canvas,
        at - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  /// 값이 하나라도 다르면 다시 그립니다.
  ///
  /// 목록은 조회할 때마다 새로 만들어지므로 identical 비교는 "같은데도 다시
  /// 그린다"로 기울어집니다. 반대로 기울면 새 기록이 안 나타납니다.
  @override
  bool shouldRepaint(_RingPainter old) =>
      !identical(old.arcs, arcs) ||
      !identical(old.dots, dots) ||
      old.trackColor != trackColor ||
      old.sleepColor != sleepColor ||
      old.feedingColor != feedingColor ||
      old.diaperColor != diaperColor ||
      old.labelColor != labelColor ||
      old.ringWidth != ringWidth ||
      old.showHourLabels != showHourLabels ||
      old.fillColor != fillColor;
}
