-- 010. 피부 분석 결과에서 진단명과 확률을 없앤다
--
-- 이 표는 성인 피부암 분류기(ISIC 계열 9종)를 전제로 만들어졌다.
--   disease_result text  — 모델이 낸 라벨 ('Melanoma' 등)
--   probability    numeric — softmax 점수
--
-- 그 분류기를 쓰지 않기로 했다. 영유아에게는 거의 없는 질환들이고, 보호자가
-- 실제로 사진을 찍는 이유(기저귀 발진, 땀띠, 태열, 지루성 피부염)는 그
-- 데이터에 라벨조차 없었다. 지금은 Claude 비전이 **진단하지 않고** 보이는
-- 것과 단계만 돌려준다.
--
-- 두 컬럼을 남겨 두면 언젠가 이 표를 쓰는 코드가 채울 값을 찾게 된다.
-- **지금 이 표를 읽고 쓰는 코드가 한 줄도 없어 바꾸는 비용이 0이다.**
--
-- level에 'normal'이 없는 것은 의도한 것이다. 사진 한 장으로 '정상'이라고
-- 말하는 것은 안심이 아니라 반대 방향의 진단이다. 체온·성장은 공인 임계값이
-- 있어 정상을 말할 수 있지만 사진에는 그 근거가 없다. assessments 표의
-- level CHECK는 그대로 3단계를 유지한다 — 피부만 그 부분집합을 쓴다.
--
-- 다시 돌려도 되게 만들었다.

alter table public.skin_analyses
  drop column if exists disease_result,
  drop column if exists probability;

alter table public.skin_analyses
  add column if not exists level        text    not null default 'caution',
  add column if not exists urgent       boolean not null default false,
  add column if not exists observations text[]  not null default '{}',
  add column if not exists unknown_note text    not null default '',
  add column if not exists advice       text    not null default '';

-- CHECK는 따로 건다. add column ... check는 재실행 시 이름이 부딪힌다.
alter table public.skin_analyses
  drop constraint if exists skin_analyses_level_check;

alter table public.skin_analyses
  add constraint skin_analyses_level_check
  check (level in ('caution', 'consult'));

comment on column public.skin_analyses.level is
  '진료 권유 단계. normal은 없다 — 사진으로 정상을 말하는 것도 진단이다';
comment on column public.skin_analyses.urgent is
  '오늘 안에 진료가 필요해 보이는 경우';
comment on column public.skin_analyses.observations is
  '사진에서 보이는 것을 옮긴 문장. 병명은 들어가지 않는다';
comment on column public.skin_analyses.unknown_note is
  '사진으로는 알 수 없는 것. 화면에서 접지 않고 늘 보여준다';
