import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../assessment/assessment.dart';
import '../assessment/temperature_rules.dart';

/// 정상·주의·상담 구간을 함께 보여주는 체온 선택기.
///
/// 고르는 동안 판정이 바뀌는 것이 핵심입니다. 이전 휠 피커는 저장한 뒤에야
/// 판정을 알 수 있었습니다.
///
/// 구간 경계는 아이 나이에 따라 달라집니다(3개월 미만은 38.0℃부터 상담 권장).
/// [ageInMonths]가 null이면 연령별 경계를 알 수 없으므로, 연령과 무관한
/// 정상 범위만 칠하고 나머지는 회색으로 둡니다. 없는 기준을 색으로 단정하지
/// 않으려는 처리입니다.
///
/// Supabase에 의존하지 않아 그대로 테스트할 수 있습니다.
class TemperaturePicker extends StatelessWidget {
  /// 지금 고른 체온(℃).
  final double value;

  /// 아이 나이(개월). 모르면 null.
  final int? ageInMonths;

  final ValueChanged<double> onChanged;

  const TemperaturePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.ageInMonths,
  });

  /// 슬라이더 범위.
  ///
  /// DB CHECK는 30~45℃까지 허용하지만, 화면에서는 35~40℃만 고를 수 있게 합니다.
  /// 40℃를 넘는 값은 이 화면으로 기록할 수 없습니다.
  static const double minTemp = 35.0;
  static const double maxTemp = 40.0;

  static const Color normalColor = Color(0xFF16A34A);
  static const Color cautionColor = Color(0xFFF59E0B);
  static const Color consultColor = Color(0xFFDC2626);
  static const Color lowColor = Color(0xFF60A5FA);
  static const Color _textColor = Color(0xFF1F2937);

  static Color colorFor(AssessmentLevel level) => switch (level) {
        AssessmentLevel.normal => normalColor,
        AssessmentLevel.caution => cautionColor,
        AssessmentLevel.consult => consultColor,
      };

  /// 0.1℃ 단위로 맞춥니다. double 연산 오차가 쌓이지 않도록 정수로 반올림합니다.
  static double snap(double raw) =>
      ((raw * 10).round() / 10).clamp(minTemp, maxTemp);

  Assessment? get _assessment {
    final months = ageInMonths;
    if (months == null) return null;
    return TemperatureRules.assess(temperatureC: value, ageInMonths: months);
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    final months = ageInMonths;
    final consultAt =
        months == null ? null : TemperatureRules.consultThreshold(months);
    final accent =
        assessment == null ? _textColor : colorFor(assessment.level);

    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)}℃',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 22,
          child: assessment == null
              ? Text(
                  '아이 정보를 등록하면 판정을 함께 보여드려요',
                  style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                )
              : Text(
                  assessment.level.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _buildBandBar(context, consultAt),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            // 구간 색상은 아래 막대가 보여주므로 트랙 자체는 눈에 띄지 않게 둡니다.
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value.clamp(minTemp, maxTemp),
            min: minTemp,
            max: maxTemp,
            divisions: ((maxTemp - minTemp) * 10).round(),
            onChanged: (raw) => onChanged(snap(raw)),
          ),
        ),
        _buildScaleLabels(context, consultAt),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepButton(context, 
                Icons.remove, () => onChanged(snap(value - 0.1))),
            const SizedBox(width: 20),
            _buildStepButton(context, Icons.add, () => onChanged(snap(value + 0.1))),
          ],
        ),
      ],
    );
  }

  /// 슬라이더 아래에 깔리는 구간 색상 막대.
  Widget _buildBandBar(BuildContext context, double? consultAt) {
    // 폭은 온도 범위에 비례합니다. 0.1℃ 단위를 정수 flex로 씁니다.
    int span(double from, double to) => ((to - from) * 10).round();

    final children = <Widget>[
      // 저체온: 기준표에 없어 프로젝트가 정한 구간입니다.
      Expanded(
        flex: span(minTemp, TemperatureRules.normalLow),
        child: _bandSegment(lowColor, isFirst: true),
      ),
      Expanded(
        flex: span(TemperatureRules.normalLow, TemperatureRules.normalHigh),
        child: _bandSegment(normalColor),
      ),
    ];

    if (consultAt == null) {
      children.add(Expanded(
        flex: span(TemperatureRules.normalHigh, maxTemp),
        child: _bandSegment(context.colors.border, isLast: true),
      ));
    } else {
      children.add(Expanded(
        flex: span(TemperatureRules.normalHigh, consultAt),
        child: _bandSegment(cautionColor),
      ));
      children.add(Expanded(
        flex: span(consultAt, maxTemp),
        child: _bandSegment(consultColor, isLast: true),
      ));
    }

    return Padding(
      // Slider의 좌우 여백과 맞춥니다.
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(height: 8, child: Row(children: children)),
    );
  }

  Widget _bandSegment(Color color, {bool isFirst = false, bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(4) : Radius.zero,
          right: isLast ? const Radius.circular(4) : Radius.zero,
        ),
      ),
    );
  }

  /// 구간 경계 눈금. 나이를 알 때만 상담 권장 경계를 표시합니다.
  Widget _buildScaleLabels(BuildContext context, double? consultAt) {
    final style = TextStyle(fontSize: 11, color: context.colors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(minTemp.toStringAsFixed(0), style: style),
          Text(TemperatureRules.normalLow.toStringAsFixed(1), style: style),
          Text(TemperatureRules.normalHigh.toStringAsFixed(1), style: style),
          if (consultAt != null)
            Text(consultAt.toStringAsFixed(1),
                style: style.copyWith(color: consultColor)),
          Text(maxTemp.toStringAsFixed(0), style: style),
        ],
      ),
    );
  }

  Widget _buildStepButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: context.colors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: _textColor),
        ),
      ),
    );
  }
}
