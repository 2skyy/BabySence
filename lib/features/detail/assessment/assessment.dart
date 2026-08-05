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
