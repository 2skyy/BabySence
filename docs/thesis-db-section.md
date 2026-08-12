# 3-6. 데이터베이스 설계

> 논문 원고용 초안. 표·그림 번호는 문서 전체 체계에 맞게 조정할 것.

## 3-6-1. 설계 개요

본 시스템의 데이터베이스는 Supabase가 제공하는 PostgreSQL을 기반으로 구축하였다.
개발 초기에는 애플리케이션 서버에 연결된 로컬 MySQL을 사용하였으나, 개발자별로
독립된 데이터베이스가 존재하여 데이터 공유가 불가능하였고 시연 환경에서도 별도의
데이터베이스 서버를 구동해야 하는 제약이 있었다. 또한 사용자 인증과 파일 저장을
각각 별도로 구현해야 하는 부담이 있었다.

이에 인증(Authentication), 관계형 데이터베이스, 파일 저장소(Storage)를 통합
제공하는 Supabase로 이전하였다. 이를 통해 팀 구성원이 동일한 데이터를 공유할 수
있게 되었으며, 비밀번호 관리와 세션 처리를 검증된 인증 서비스에 위임함으로써
보안 취약점의 발생 가능성을 낮추었다.

전체 스키마는 19개 테이블로 구성된다. 사용자 계정 정보는 Supabase가 관리하는
`auth.users` 테이블에 저장되며, 본 시스템이 정의한 테이블들은 이를 최상위 부모로
참조한다.

## 3-6-2. 테이블 구성

시스템을 구성하는 테이블과 주요 컬럼은 〈표 3-6-1〉과 같다.

**〈표 3-6-1〉 데이터베이스 테이블 구성**

| 구분 | 테이블명 | 역할 | 주요 컬럼 |
|---|---|---|---|
| 사용자 | `profiles` | 보호자 프로필 | id(PK, FK), name |
| 사용자 | `babies` | 아이 정보 | id(PK), user_id(FK), name, sex, birth_date |
| 사용자 | `device_tokens` | 푸시 알림 토큰 | id(PK), user_id(FK), fcm_token, platform |
| 육아 기록 | `growth_records` | 성장 기록 | id(PK), baby_id(FK), recorded_on, height_cm, weight_kg |
| 육아 기록 | `feeding_records` | 수유 기록 | id(PK), baby_id(FK), feeding_type, amount_ml, fed_at |
| 육아 기록 | `diaper_records` | 배변 기록 | id(PK), baby_id(FK), diaper_type, stool_state, recorded_at |
| 육아 기록 | `sleep_records` | 수면 기록 및 소음 집계 | id(PK), baby_id(FK), sleep_type, started_at, ended_at, average_db, max_db, sample_count |
| 육아 기록 | `temperature_records` | 체온 기록 | id(PK), baby_id(FK), temperature_c, measured_at |
| 육아 기록 | `temperature_symptoms` | 체온 기록의 동반 증상 | temperature_record_id + symptom(복합 PK) |
| 예방접종 | `vaccines` | 표준 예방접종 일정 | id(PK), code, name, recommended_age_months, dose_number |
| 예방접종 | `vaccination_records` | 아이별 접종 이력 | id(PK), baby_id(FK), vaccine_id(FK), scheduled_on, vaccinated_on |
| AI 분석 | `skin_analyses` | 피부 관찰 이력 | id(PK), baby_id(FK), image_path, level, urgent, observations, advice |
| 판정 | `assessments` | 3단계 판정 및 행동 가이드 | id(PK), baby_id(FK), domain, level, guide_text, inputs, rule_version, assessed_at |

기본키는 `uuid` 타입으로 통일하였다. 이는 Supabase 인증 사용자 식별자가 `uuid`
형식이며, 클라이언트가 서버와의 통신 없이 식별자를 미리 생성할 수 있어 오프라인
입력 후 동기화에 유리하기 때문이다.

선택형 입력값은 화면에 표시되는 한글 문구 대신 영문 코드값으로 저장하였다.
표시 문구가 변경되더라도 저장된 데이터를 함께 수정할 필요가 없도록 하기 위함이며,
저장 가능한 값은 〈표 3-6-2〉와 같이 CHECK 제약조건으로 제한하였다.

**〈표 3-6-2〉 선택형 컬럼의 코드값 정의**

| 테이블 | 컬럼 | 코드값 | 표시 문구 |
|---|---|---|---|
| `babies` | sex | male / female | 남아 / 여아 |
| `feeding_records` | feeding_type | formula / breast / solid | 분유 / 모유(직수) / 이유식 |
| `diaper_records` | diaper_type | urine / stool / mixed | 소변 / 대변 / 혼합 |
| `diaper_records` | stool_state | golden / green / loose / hard | 황금변 / 녹변 / 묽음 / 단단함 |
| `sleep_records` | sleep_type | night / nap | 밤잠 / 낮잠 |
| `temperature_symptoms` | symptom | cough / runny_nose / rash / vomit / diarrhea | 기침 / 콧물 / 발진 / 구토 / 설사 |

## 3-6-3. 엔티티 간 관계

테이블 간 관계는 〈그림 3-6-1〉과 같다.

**〈그림 3-6-1〉 데이터베이스 ERD**

*(ERD 다이어그램 삽입 위치)*

관계의 구조는 다음과 같다. 인증 사용자(`auth.users`)는 보호자 프로필과 1:1 관계를
가지며, 아이 정보 및 푸시 알림 토큰과는 1:N 관계를 가진다. 한 보호자가 여러 명의
아이를 등록할 수 있고 여러 대의 기기를 사용할 수 있기 때문이다.

육아 기록에 해당하는 테이블들은 보호자가 아닌 **아이(`babies`)를 참조한다.**
형제자매를 등록하더라도 각 아이의 기록이 분리되어 관리되며, 아이 정보가 삭제되면
관련 기록도 함께 삭제되도록 참조 무결성 옵션을 설정하였다.

체온 기록의 동반 증상(`temperature_symptoms`)은 체온 기록에 종속되는 2단계 자식
엔티티이다. 예방접종의 경우 표준 접종 일정(`vaccines`)이 모든 사용자가 공유하는
참조 데이터이므로, 아이와 예방접종은 다대다(M:N) 관계를 이루며 이를
`vaccination_records`가 연결한다.

## 3-6-4. 주요 설계 결정

### 가. 다중 선택 항목의 정규화

체온 기록 시 입력하는 동반 증상은 복수 선택이 가능하다. 이를 하나의 컬럼에 배열이나
문자열로 저장할 경우 특정 증상을 기준으로 한 조회가 어렵고 값의 유효성을 보장하기
어렵다. 따라서 `temperature_symptoms` 연결 테이블로 분리하고, 기록 식별자와 증상
코드를 복합 기본키로 지정하여 동일한 증상이 중복 등록되지 않도록 하였다.

한편 사용자 인터페이스의 '없음' 항목은 별도의 코드값으로 저장하지 않는다. 해당
기록에 연결된 증상 행이 존재하지 않는 상태가 곧 증상 없음을 의미하므로, 불필요한
코드값을 두지 않고 관계의 부재로 표현하였다.

### 나. 제약조건을 통한 데이터 무결성 확보

응용 프로그램의 검증 로직만으로는 잘못된 데이터의 저장을 완전히 막을 수 없다.
이에 논리적으로 성립할 수 없는 조합을 데이터베이스 차원에서 거부하도록 CHECK
제약조건을 설정하였다.

대표적으로 배변 기록의 경우, 배변 유형이 '소변'인데 대변 상태가 함께 기록되는 것은
모순이므로 이러한 조합을 거부한다. 성장 기록에서는 키와 몸무게가 모두 비어 있는
무의미한 행이 저장되지 않도록 하였으며, 측정일 기준으로 하루에 한 건만 유지되도록
고유 제약조건을 두었다. 수면 기록에서는 종료 시각이 시작 시각보다 이전일 수 없도록
제한하였다.

### 다. 행 수준 보안을 이용한 사용자 데이터 격리

모든 테이블에 PostgreSQL의 행 수준 보안(Row Level Security, RLS)을 적용하여, 현재
인증된 사용자가 소유한 행만 조회 및 수정할 수 있도록 하였다. 육아 기록 테이블들은
아이 정보를 경유하여 소유권을 확인하며, 수면 중 소음 측정값과 체온 동반 증상은 두
단계를 거쳐 확인한다.

이 방식은 응용 프로그램이 조회 조건을 누락하더라도 타인의 데이터가 노출되지 않는
다층 방어 구조를 형성한다. 실제로 응용 프로그램의 조회 코드에는 사용자 식별자
조건이 포함되지 않으며, 소유권 검증은 전적으로 데이터베이스가 담당한다.

### 라. 파생 데이터의 비저장

계산을 통해 얻을 수 있는 값은 저장하지 않는 것을 원칙으로 하였다. 수면 시간은 시작
시각과 종료 시각의 차이로 산출하며, 성장 백분위는 WHO 성장 표준의 LMS 파라미터를
이용해 조회 시점에 계산한다. 이러한 값을 별도로 저장할 경우 원본 데이터가 수정되었을
때 불일치가 발생할 수 있기 때문이다.
