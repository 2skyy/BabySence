/// 판정 단계. enum 이름이 assessments.level의 CHECK 제약
/// (`normal` / `caution` / `consult`)과 그대로 일치해야 합니다.
enum AssessmentLevel {
  normal('정상'),
  caution('주의'),
  consult('상담 권장');

  const AssessmentLevel(this.label);

  /// 화면에 표시하는 이름.
  final String label;
}

/// 판정 영역. enum 이름이 assessments.domain의 CHECK 제약과 일치해야 합니다.
enum AssessmentDomain {
  temperature('체온'),
  feeding('수유'),
  sleep('수면'),
  diaper('배변'),
  growth('성장'),
  noise('소음'),
  skin('피부'),
  overall('종합');

  const AssessmentDomain(this.label);

  /// 화면에 표시하는 이름.
  final String label;
}

/// 규칙 엔진이 낸 판정 하나.
class Assessment {
  final AssessmentDomain domain;
  final AssessmentLevel level;

  /// 판정에 대응하는 행동 가이드 문장.
  final String guideText;

  /// 판정 시점의 입력값 스냅샷.
  /// 원본 기록이 수정되거나 삭제되어도 판정 근거가 남습니다.
  final Map<String, dynamic> inputs;

  /// 적용된 임계값 규칙의 버전. 기준을 바꾸면 올려야 합니다.
  final String ruleVersion;

  /// 화면에 보여줄 단계 이름.
  ///
  /// 소음은 수면 환경 문제이지 아이의 몸 상태가 아닙니다. 여기에
  /// '상담 권장'을 쓰면 소음 때문에 병원에 가라는 말로 읽힙니다.
  /// 같은 `consult` 단계라도 소음에서는 '개선 권장'으로 부릅니다.
  /// DB에 저장되는 값은 그대로 `consult`이므로 CHECK 제약과 3단계 구조는
  /// 유지됩니다.
  String get levelLabel {
    if (domain == AssessmentDomain.noise &&
        level == AssessmentLevel.consult) {
      return '개선 권장';
    }
    return level.label;
  }

  /// 판정 시각. 저장 전에는 null입니다 — DB가 넣어 줍니다.
  final DateTime? assessedAt;

  const Assessment({
    required this.domain,
    required this.level,
    required this.guideText,
    required this.inputs,
    required this.ruleVersion,
    this.assessedAt,
  });

  Map<String, dynamic> toRow(String babyId) => {
        'baby_id': babyId,
        'domain': domain.name,
        'level': level.name,
        'guide_text': guideText,
        'inputs': inputs,
        'rule_version': ruleVersion,
      };
}
