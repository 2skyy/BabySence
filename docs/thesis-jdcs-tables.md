# 표 1~4 — JDCS 형식 (영문 내용)

JDCS 규정:
- **표·그림 안의 모든 내용은 영문**으로 작성한다.
- 표 캡션은 **표 위**에, 국문(`표 N.`)과 영문(`Table N.`) **두 줄**로 단다.
- 영문 제목은 **맨 앞 단어의 첫 글자만 대문자**로 쓴다.
- 표 안 글꼴: 돋움 7.5pt, 장평 100, 자간 −3, 양쪽정렬, 줄간격 120%.
- 캡션 글꼴: 국문 돋움 8.5pt(장평 95, 자간 −8) / 영문 Arial 8.5pt(장평 100, 자간 −2),
  줄간격 130%, 내어쓰기 22pt.
- 표는 **글자처럼 취급**으로 넣고 캡션 여백은 모두 0.

---

## 표 1

```
표 1. 선행 연구의 초점과 본 연구의 차이
Table 1. Focus of prior studies compared with this study
```

| Study | Data and subjects | Method | Output | End user | Action guide |
|---|---|---|---|---|---|
| Kim et al. [8] | KDCA influenza vaccination records and NHIS claims / adults aged 65+ | Random forest, case-crossover | Candidate adverse-event factors (test accuracy approx. 0.70) | Researchers, health authorities | X |
| Sutton et al. [9] | Existing CDSS literature / clinical settings | Systematic review | Benefits, risks, and success factors of CDSS | Clinicians | △ |
| Jang et al. [10] | Online parenting community posts / mothers of infants | Text mining | Information-seeking types (anxiety expression 44.83%) | Researchers | X |
| Hong et al. [11] | Caregiver-entered records / infants | Record management application | Storage and retrieval of numeric data | Caregivers | X |
| This study (BabySense) | Caregiver-entered status data / infants aged 0-35 months | Rule engine based on authoritative guidelines, LLM, CNN | Three-level judgment and action guide | Caregivers | O |

`O: provided, △: provided to medical professionals only, X: not provided`

---

## 표 2

```
표 2. 영유아 케어 지원 플랫폼 8종의 특징·지표 및 의사결정 지원 기능 비교
Table 2. Comparison of eight infant care platforms by feature, metric, and decision support capability
```

| Service | Type | Main feature | Main metrics | Integrated analysis | Interpretation | Action guide |
|---|---|---|---|---|---|---|
| Vaccination Helper | Public information | National schedule and history, reminders | Vaccination history | X | X | X |
| Momsholic Baby | Community | Peer experience sharing | None structured | X | X | X |
| Isarang | Public information | Public service information, limited records | General childcare information | X | X | X |
| MomsDiary | Record (narrative) | Diary, printed growth album reward | Unstructured diary text | X | X | X |
| PiyoLog | Record (quantitative) | One-touch entry, co-caregiver sharing | Feeding, sleep, diaper | △ | X | X |
| Fever Coach | DSS (single metric) | Antipyretic reminders, visit decision | Temperature, medication history | △ | △ | △ |
| BabyTime | Record (quantitative) | Timer entry, growth curve comparison | Feeding, sleep, diaper, growth | △ | X | X |
| Baby Daybook | Record (quantitative) | Widget and watch sync, sleep tracking | Feeding, sleep, diaper | △ | X | X |
| BabySense | DSS (integrated) | Rule engine, LLM action guide, skin classifier | Temperature, symptoms, feeding, sleep, diaper, growth, vaccination, skin, noise | O | O | O |

`O: provided, △: partially provided (single metric or statistics only), X: not provided`
`Record and retrieval functions are excluded from the comparison because all eight services provide them.`

---

## 표 3

```
표 3. 연령대별 체온 판단 기준
Table 3. Age-specific criteria for body temperature assessment
```

| Age | Normal | Caution | Consultation recommended |
|---|---|---|---|
| 0-3 months | 36.5-37.5 ℃ | 37.5-38.0 ℃ | 38.0 ℃ or above (immediate visit) |
| 3-6 months | 36.5-37.5 ℃ | 37.5-38.5 ℃ | 38.5 ℃ or above |
| 6 months or older | 36.5-37.5 ℃ | 37.5-39.0 ℃ | 39.0 ℃ or above |

> **변경한 곳** — 6개월 이상 행의 주의 하한을 **38.0 → 37.5**로 고쳤습니다.
> 원래 표는 정상이 37.5까지, 주의가 38.0부터여서 **37.5~38.0 ℃ 구간이 어느 단계에도
> 속하지 않았습니다.** 0~3개월과 3~6개월은 37.5에서 이어지므로 같은 방식으로 맞췄고,
> 구현된 판정 엔진도 이 값을 씁니다.

단위 규정에 따라 ℃ 앞은 띄우지 않고, 그 외 단위는 수치와 한 칸 띄웁니다.

---

## 표 4

```
표 4. 사용자 경험 평가 질문 구성
Table 4. Composition of user experience evaluation questions
```

| Area | Question |
|---|---|
| Prior experience | What methods do you usually rely on when judging your child's condition, such as web search, asking acquaintances, or contacting a clinic? |
| Usability | Did you find entering temperature, feeding, and sleep records intuitive? Was any part difficult? |
| Result confidence | Were the three-level results and action guides helpful for your actual decisions? |
| Change in anxiety | After seeing the result, did you feel less anxious about judging the situation than before? |
| Suggestions | What additional features or improvements did you find necessary during actual use? |

---

## 본문 인용 표기

JDCS는 참고문헌 **번호로** 인용합니다. 저자명으로 인용할 경우 연도를 쓰지 않습니다.

| 고칠 것 | 고친 뒤 |
|---|---|
| `Kim 외(2021)의 연구는` | `Kim의 연구는 [8]` 또는 `선행 연구 [8]은` |
| `Sutton 등[9]에 따르면` | 그대로 두어도 되나 `[9]에 따르면`이 더 안전 |
| `장혜인 외(2025)` | `[10]` |

본문에서 `(2021)`, `(2025)` 같은 연도 표기를 모두 찾아 지워야 합니다.
