-- ============================================================================
-- BabySense — Supabase(PostgreSQL) 스키마
--
-- 사용법: Supabase 대시보드 → SQL Editor에 전체 붙여넣기 후 Run
-- 설계 문서: docs/erd.md
--
-- 구성: 1) 회원가입 트리거  2) 테이블  3) 인덱스  4) RLS(소유권 함수 포함)
--       5) 예방접종 마스터 데이터  6) Storage 버킷
-- ============================================================================


-- ── 개발 중 초기화가 필요할 때만 주석을 해제하세요 ──────────────────────────
-- 경고: 아래 블록은 모든 데이터를 삭제합니다. 운영 환경에서는 절대 실행하지 마세요.
--
-- drop table if exists public.temperature_symptoms  cascade;
-- drop table if exists public.temperature_records   cascade;
-- drop table if exists public.sleep_noise_logs      cascade;
-- drop table if exists public.sleep_records         cascade;
-- drop table if exists public.diaper_records        cascade;
-- drop table if exists public.feeding_records       cascade;
-- drop table if exists public.growth_records        cascade;
-- drop table if exists public.vaccination_records   cascade;
-- drop table if exists public.vaccines              cascade;
-- drop table if exists public.skin_analyses         cascade;
-- drop table if exists public.assessments           cascade;
-- drop table if exists public.device_tokens         cascade;
-- drop table if exists public.baby_invites          cascade;
-- drop table if exists public.baby_members          cascade;
-- drop table if exists public.babies                cascade;
-- drop table if exists public.profiles              cascade;
-- drop function if exists public.handle_new_user()          cascade;
-- drop function if exists public.owns_baby(uuid)            cascade;
-- drop function if exists public.owns_sleep_record(uuid)    cascade;
-- drop function if exists public.owns_temp_record(uuid)     cascade;
-- ────────────────────────────────────────────────────────────────────────────


-- ============================================================================
-- 1. 회원가입 트리거
-- ============================================================================

-- 회원가입 시 profiles 행을 자동 생성합니다.
--
-- 이름이 담기는 키가 가입 경로마다 다릅니다.
--   이메일 가입 : signUp(data: {'name': ...})  → 'name'
--   구글        → 'full_name' (또는 'name')
--   카카오      → 'nickname'  (또는 'user_name')
-- 그래서 순서대로 시도하고, 전부 없으면 이메일 아이디 부분을 씁니다.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'name',      ''),
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'nickname',  ''),
      nullif(new.raw_user_meta_data ->> 'user_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      '이름 없음'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ============================================================================
-- 2. 테이블
-- ============================================================================

-- 2.1 보호자 프로필 ----------------------------------------------------------
create table public.profiles (
  id          uuid        primary key references auth.users (id) on delete cascade,
  name        text        not null,
  created_at  timestamptz not null default now()
);

comment on table public.profiles is '보호자 프로필. auth.users와 1:1, 회원가입 트리거로 자동 생성됨';


-- 2.2 아이 -------------------------------------------------------------------
create table public.babies (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  sex         text        not null check (sex in ('male', 'female')),
  birth_date  date        not null,
  created_at  timestamptz not null default now()
);

comment on column public.babies.sex is 'WHO 성장곡선 계산에 필수 (남아/여아 기준표가 다름)';


-- 2.2.1 함께 키우기 구성원 ----------------------------------------------------
-- owns_baby()가 이 표를 보고 접근 권한을 판단하므로, 함수보다 먼저 있어야 합니다.
create table if not exists public.baby_members (
  baby_id    uuid        not null references public.babies (id)   on delete cascade,
  user_id    uuid        not null references auth.users (id)      on delete cascade,
  role       text        not null default 'member'
                         check (role in ('owner', 'member')),
  joined_at  timestamptz not null default now(),

  primary key (baby_id, user_id)
);

comment on table  public.baby_members      is '한 아이를 함께 보는 보호자 목록';
comment on column public.baby_members.role is 'owner=아이를 만든 사람(초대·삭제 가능), member=초대받은 사람';

create index if not exists idx_baby_members_user on public.baby_members (user_id);


-- 2.2.2 함께 키우기 초대 ------------------------------------------------------
create table if not exists public.baby_invites (
  code        text        primary key,
  baby_id     uuid        not null references public.babies (id) on delete cascade,
  created_by  uuid        not null references auth.users (id)    on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  used_at     timestamptz,
  used_by     uuid        references auth.users (id) on delete set null
);

comment on table  public.baby_invites            is '함께 키우기 초대 코드. 한 번 쓰면 만료됩니다';
comment on column public.baby_invites.code       is '사람이 불러주기 쉬운 8자리. 혼동되는 0/O/1/I는 뺍니다';
comment on column public.baby_invites.expires_at is '기본 7일. 코드가 영원히 살아 있으면 유출 시 계속 위험합니다';

create index if not exists idx_baby_invites_baby on public.baby_invites (baby_id, created_at desc);


-- 2.3 성장 기록 --------------------------------------------------------------
create table public.growth_records (
  id           uuid        primary key default gen_random_uuid(),
  baby_id      uuid        not null references public.babies (id) on delete cascade,
  recorded_on  date        not null,
  height_cm    numeric(4,1) check (height_cm between 20 and 150),
  weight_kg    numeric(4,2) check (weight_kg between 0.5 and 40),
  created_at   timestamptz not null default now(),

  -- 키와 몸무게가 동시에 비어 있는 무의미한 행을 막습니다.
  constraint growth_has_value check (height_cm is not null or weight_kg is not null),
  constraint growth_one_per_day unique (baby_id, recorded_on)
);


-- 2.4 수유 기록 --------------------------------------------------------------
create table public.feeding_records (
  id            uuid        primary key default gen_random_uuid(),
  baby_id       uuid        not null references public.babies (id) on delete cascade,
  feeding_type  text        not null check (feeding_type in ('formula', 'breast', 'solid')),
  amount_ml     integer     check (amount_ml between 0 and 2000),
  fed_at        timestamptz not null,
  created_at    timestamptz not null default now()
);

comment on column public.feeding_records.feeding_type is 'formula=분유, breast=모유(직수), solid=이유식';
comment on column public.feeding_records.amount_ml   is '모유(직수)는 계량이 불가능하므로 NULL 허용';


-- 2.5 배변 기록 --------------------------------------------------------------
create table public.diaper_records (
  id           uuid        primary key default gen_random_uuid(),
  baby_id      uuid        not null references public.babies (id) on delete cascade,
  diaper_type  text        not null check (diaper_type in ('urine', 'stool', 'mixed')),
  stool_state  text        check (stool_state in ('golden', 'green', 'loose', 'hard')),
  recorded_at  timestamptz not null,
  created_at   timestamptz not null default now(),

  -- 소변인데 대변 상태가 기록되는 모순을 DB가 거부합니다.
  constraint diaper_stool_state_consistent check (
    (diaper_type = 'urine'             and stool_state is null)
    or (diaper_type in ('stool', 'mixed') and stool_state is not null)
  )
);

comment on column public.diaper_records.diaper_type is 'urine=소변, stool=대변, mixed=혼합';
comment on column public.diaper_records.stool_state is 'golden=황금변, green=녹변, loose=묽음, hard=단단함';


-- 2.6 수면 기록 --------------------------------------------------------------
create table public.sleep_records (
  id          uuid        primary key default gen_random_uuid(),
  baby_id     uuid        not null references public.babies (id) on delete cascade,
  sleep_type  text        not null check (sleep_type in ('night', 'nap')),
  started_at  timestamptz not null,
  ended_at    timestamptz,
  created_at  timestamptz not null default now(),

  constraint sleep_period_valid check (ended_at is null or ended_at > started_at)
);

comment on column public.sleep_records.sleep_type is 'night=밤잠, nap=낮잠';
comment on column public.sleep_records.ended_at   is 'NULL이면 측정 진행 중. 수면 시간은 저장하지 않고 조회 시 계산';


-- 2.7 수면 중 소음 로그 ------------------------------------------------------
-- 건수가 가장 많은 테이블입니다(NoiseTracker가 30건씩 배치 전송).
-- 저장 공간과 인덱스 효율을 위해 유일하게 bigint PK를 사용합니다.
create table public.sleep_noise_logs (
  id               bigint       primary key generated always as identity,
  sleep_record_id  uuid         not null references public.sleep_records (id) on delete cascade,
  measured_at      timestamptz  not null,
  decibel          numeric(5,2) not null check (decibel between 0 and 200)
);

comment on column public.sleep_noise_logs.decibel is 'NoiseTracker에서 보정(-8dB) 및 이동평균 처리를 마친 최종 값';


-- 2.8 체온 기록 --------------------------------------------------------------
create table public.temperature_records (
  id             uuid         primary key default gen_random_uuid(),
  baby_id        uuid         not null references public.babies (id) on delete cascade,
  temperature_c  numeric(3,1) not null check (temperature_c between 30.0 and 45.0),
  measured_at    timestamptz  not null,
  created_at     timestamptz  not null default now()
);

-- 증상은 다중 선택이므로 별도 테이블로 정규화합니다.
create table public.temperature_symptoms (
  temperature_record_id uuid not null references public.temperature_records (id) on delete cascade,
  symptom               text not null check (symptom in ('cough', 'runny_nose', 'rash', 'vomit', 'diarrhea')),

  primary key (temperature_record_id, symptom)
);

comment on table  public.temperature_symptoms         is 'UI의 ''없음''은 저장하지 않음. 행이 하나도 없는 상태가 곧 ''없음''';
comment on column public.temperature_symptoms.symptom is 'cough=기침, runny_nose=콧물, rash=발진, vomit=구토, diarrhea=설사';


-- 2.9 예방접종 ---------------------------------------------------------------
-- 국가 표준 접종 일정. 모든 사용자가 공유하는 읽기 전용 참조 데이터입니다.
create table public.vaccines (
  id                     smallint primary key generated always as identity,
  code                   text     not null unique,
  name                   text     not null,
  recommended_age_label  text     not null,
  recommended_age_months smallint not null check (recommended_age_months >= 0),
  dose_number            smallint not null default 1,
  display_order          smallint not null
);

comment on column public.vaccines.recommended_age_label  is '화면 표시용 문구. 예: 생후 15~18개월';
comment on column public.vaccines.recommended_age_months is '예정일 계산용 개월 수. scheduled_on = birth_date + N개월';

-- 아이별 접종 이력. babies ↔ vaccines의 M:N을 해소하는 연결 테이블입니다.
create table public.vaccination_records (
  id             uuid        primary key default gen_random_uuid(),
  baby_id        uuid        not null references public.babies (id) on delete cascade,
  vaccine_id     smallint    not null references public.vaccines (id) on delete restrict,
  scheduled_on   date,
  vaccinated_on  date,
  created_at     timestamptz not null default now(),

  constraint vaccination_unique_per_baby unique (baby_id, vaccine_id)
);

comment on column public.vaccination_records.scheduled_on  is '예정일. FCM 알림 발송 기준';
comment on column public.vaccination_records.vaccinated_on is 'NULL이면 미접종(예정), 값이 있으면 완료';


-- 2.10 AI 분석 이력 ----------------------------------------------------------
-- 파이썬 AI 서버가 반환한 원본 라벨을 그대로 저장합니다.
-- 한글 변환은 앱에서 처리해야 모델을 교체해도 과거 이력이 깨지지 않습니다.
create table public.skin_analyses (
  id              uuid         primary key default gen_random_uuid(),
  baby_id         uuid         not null references public.babies (id) on delete cascade,
  image_path      text         not null,
  disease_result  text         not null,
  probability     numeric(5,2) not null check (probability between 0 and 100),
  analyzed_at     timestamptz  not null default now()
);

comment on column public.skin_analyses.image_path is 'Storage 경로. 형식: {user_id}/{baby_id}/{파일명}';


-- 2.11 판정 결과 -------------------------------------------------------------
-- 규칙 엔진의 '정상 / 주의 / 상담 권장' 3단계 판정과 행동 가이드를 보관한다.
--
-- 일별 집계에 종속시키지 않고 아기를 직접 참조한다. 체온이나 소음처럼 입력
-- 즉시 판정하는 기능은 하루에 여러 건의 판정이 발생하며, 발열 추이를 보려면
-- 그 이력이 모두 남아야 하기 때문이다.
create table public.assessments (
  id            uuid        primary key default gen_random_uuid(),
  baby_id       uuid        not null references public.babies (id) on delete cascade,
  domain        text        not null check (domain in (
                              'temperature', 'feeding', 'sleep', 'diaper',
                              'growth', 'noise', 'skin', 'overall')),
  level         text        not null check (level in ('normal', 'caution', 'consult')),
  guide_text    text        not null,
  inputs        jsonb       not null,
  rule_version  text        not null,
  assessed_at   timestamptz not null default now()
);

comment on column public.assessments.level        is 'normal=정상, caution=주의, consult=상담 권장';
comment on column public.assessments.guide_text   is '판정에 대응하는 행동 가이드 문장';
comment on column public.assessments.inputs       is '판정 시점의 입력값 스냅샷. 원본 기록이 수정되어도 판정 이력이 보존된다';
comment on column public.assessments.rule_version is '적용된 임계값 규칙의 버전. 판단 근거의 추적에 사용';


-- 2.12 FCM 토큰 --------------------------------------------------------------
create table public.device_tokens (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  fcm_token   text        not null unique,
  platform    text        not null check (platform in ('android', 'ios')),
  updated_at  timestamptz not null default now()
);

comment on table public.device_tokens is '한 사용자가 여러 기기를 사용할 수 있으므로 1:N';


-- ============================================================================
-- 3. 인덱스
-- ============================================================================
-- 조회 패턴: "특정 아이의 기록을 최신순으로" → (baby_id, 시각 desc) 복합 인덱스

create index idx_babies_user              on public.babies              (user_id);
create index idx_growth_baby_date         on public.growth_records      (baby_id, recorded_on desc);
create index idx_feeding_baby_time        on public.feeding_records     (baby_id, fed_at       desc);
create index idx_diaper_baby_time         on public.diaper_records      (baby_id, recorded_at desc);
create index idx_sleep_baby_time          on public.sleep_records       (baby_id, started_at  desc);
create index idx_temperature_baby_time    on public.temperature_records (baby_id, measured_at desc);
create index idx_skin_baby_time           on public.skin_analyses       (baby_id, analyzed_at desc);
create index idx_vaccination_baby         on public.vaccination_records (baby_id);
create index idx_assessments_baby_time    on public.assessments         (baby_id, assessed_at desc);
create index idx_device_tokens_user       on public.device_tokens       (user_id);

-- 소음 그래프는 시간 오름차순으로 그리므로 desc를 붙이지 않습니다.
create index idx_noise_record_time        on public.sleep_noise_logs    (sleep_record_id, measured_at);


-- ============================================================================
-- 4. RLS (Row Level Security)
-- ============================================================================
-- 앱 쿼리에서 조건을 빠뜨려도 다른 사용자의 데이터가 조회되지 않도록
-- DB 레벨에서 차단합니다.


-- 4.0 소유권 검사 함수 -------------------------------------------------------
-- 아래 정책들이 재사용합니다.
--
-- security definer로 선언해 babies 테이블의 RLS를 우회합니다(무한 재귀 방지).
-- 현재 로그인 사용자의 소유 여부만 boolean으로 돌려주므로 정보가 새지 않습니다.
--
-- language sql 함수는 생성 시점에 본문이 검증되므로, 참조하는 테이블이
-- 모두 만들어진 뒤인 여기에 있어야 합니다.

create or replace function public.owns_baby(p_baby_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.baby_members m
    where m.baby_id = p_baby_id
      and m.user_id = auth.uid()
  );
$$;

-- 초대·구성원 삭제처럼 소유자만 할 수 있는 일에 씁니다.
create or replace function public.is_baby_owner(p_baby_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.baby_members m
    where m.baby_id = p_baby_id
      and m.user_id = auth.uid()
      and m.role = 'owner'
  );
$$;

create or replace function public.owns_sleep_record(p_sleep_record_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.sleep_records s
    where s.id = p_sleep_record_id
      and public.owns_baby(s.baby_id)
  );
$$;

create or replace function public.owns_temp_record(p_temperature_record_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.temperature_records t
    where t.id = p_temperature_record_id
      and public.owns_baby(t.baby_id)
  );
$$;


-- 4.1 RLS 활성화 -------------------------------------------------------------

alter table public.profiles              enable row level security;
alter table public.babies                enable row level security;
alter table public.growth_records        enable row level security;
alter table public.feeding_records       enable row level security;
alter table public.diaper_records        enable row level security;
alter table public.sleep_records         enable row level security;
alter table public.sleep_noise_logs      enable row level security;
alter table public.temperature_records   enable row level security;
alter table public.temperature_symptoms  enable row level security;
alter table public.vaccines              enable row level security;
alter table public.vaccination_records   enable row level security;
alter table public.skin_analyses         enable row level security;
alter table public.assessments           enable row level security;
alter table public.device_tokens         enable row level security;


-- 4.2 본인 행만 접근 ---------------------------------------------------------
create policy profiles_own on public.profiles
  for all to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 아이는 '만든 사람'이 아니라 '구성원'이 봅니다(함께 키우기).
--
-- `user_id = auth.uid()`를 함께 두는 이유는 `insert ... returning` 때문입니다.
-- RETURNING으로 나가는 행에도 이 정책이 걸리는데, 구성원을 등록하는
-- on_baby_created는 AFTER 트리거라 그 시점에 아직 실행되지 않았습니다.
-- 이 조건이 없으면 아이 등록이 통째로 실패합니다(migrations/005 참고).
create policy babies_select on public.babies
  for select to authenticated
  using (public.owns_baby(id) or user_id = auth.uid());

create policy babies_insert on public.babies
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy babies_update on public.babies
  for update to authenticated
  using (public.owns_baby(id))
  with check (public.owns_baby(id));

-- 삭제는 되돌릴 수 없고 기록이 전부 사라지므로 소유자만 할 수 있습니다.
create policy babies_delete on public.babies
  for delete to authenticated
  using (public.is_baby_owner(id));

create policy device_tokens_own on public.device_tokens
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- 4.3 babies를 경유해 소유권 확인 --------------------------------------------
create policy growth_own on public.growth_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy feeding_own on public.feeding_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy diaper_own on public.diaper_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy sleep_own on public.sleep_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy temperature_own on public.temperature_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy vaccination_own on public.vaccination_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy skin_own on public.skin_analyses
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy assessments_own on public.assessments
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));


-- 4.4 2단계 경유 -------------------------------------------------------------
create policy noise_own on public.sleep_noise_logs
  for all to authenticated
  using (public.owns_sleep_record(sleep_record_id))
  with check (public.owns_sleep_record(sleep_record_id));

create policy temperature_symptoms_own on public.temperature_symptoms
  for all to authenticated
  using (public.owns_temp_record(temperature_record_id))
  with check (public.owns_temp_record(temperature_record_id));


-- 4.5 공용 참조 데이터 (읽기 전용) -------------------------------------------
create policy vaccines_read on public.vaccines
  for select to authenticated
  using (true);


-- ============================================================================
-- 5. 예방접종 마스터 데이터 (생후 0~24개월)
-- ============================================================================
-- 출처: 질병관리청 표준예방접종일정표 기준 정리.
-- 참고용 데이터이며 실제 접종은 의료기관 안내를 따라야 합니다.
-- 만 4세 이후 일정(DTaP 5차, 폴리오 4차, MMR 2차 등)은 앱의 대상 연령을 벗어나
-- 포함하지 않았습니다. 필요 시 같은 형식으로 추가하세요.

insert into public.vaccines (code, name, recommended_age_label, recommended_age_months, dose_number, display_order) values
  ('HEPB_1',  'B형간염 1차',           '출생 직후',        0,  1,  1),
  ('BCG',     'BCG (피내용)',          '생후 4주 이내',    0,  1,  2),
  ('HEPB_2',  'B형간염 2차',           '생후 1개월',       1,  2,  3),
  ('DTAP_1',  'DTaP 1차',              '생후 2개월',       2,  1,  4),
  ('IPV_1',   '폴리오 1차',            '생후 2개월',       2,  1,  5),
  ('HIB_1',   'Hib 1차',               '생후 2개월',       2,  1,  6),
  ('PCV_1',   '폐렴구균 1차',          '생후 2개월',       2,  1,  7),
  ('ROTA_1',  '로타바이러스 1차',      '생후 2개월',       2,  1,  8),
  ('DTAP_2',  'DTaP 2차',              '생후 4개월',       4,  2,  9),
  ('IPV_2',   '폴리오 2차',            '생후 4개월',       4,  2, 10),
  ('HIB_2',   'Hib 2차',               '생후 4개월',       4,  2, 11),
  ('PCV_2',   '폐렴구균 2차',          '생후 4개월',       4,  2, 12),
  ('ROTA_2',  '로타바이러스 2차',      '생후 4개월',       4,  2, 13),
  ('HEPB_3',  'B형간염 3차',           '생후 6개월',       6,  3, 14),
  ('DTAP_3',  'DTaP 3차',              '생후 6개월',       6,  3, 15),
  ('HIB_3',   'Hib 3차',               '생후 6개월',       6,  3, 16),
  ('PCV_3',   '폐렴구균 3차',          '생후 6개월',       6,  3, 17),
  ('ROTA_3',  '로타바이러스 3차',      '생후 6개월 (RV5)', 6,  3, 18),
  ('IPV_3',   '폴리오 3차',            '생후 6~18개월',    6,  3, 19),
  ('FLU',     '인플루엔자',            '생후 6개월 이후 매년', 6, 1, 20),
  ('MMR_1',   'MMR 1차',               '생후 12~15개월',  12,  1, 21),
  ('VAR',     '수두',                  '생후 12~15개월',  12,  1, 22),
  ('HIB_4',   'Hib 4차',               '생후 12~15개월',  12,  4, 23),
  ('PCV_4',   '폐렴구균 4차',          '생후 12~15개월',  12,  4, 24),
  ('JE_1',    '일본뇌염(불활성화) 1차', '생후 12~23개월', 12,  1, 25),
  ('JE_2',    '일본뇌염(불활성화) 2차', '1차 후 7~30일',  12,  2, 26),
  ('HEPA_1',  'A형간염 1차',           '생후 12~23개월',  12,  1, 27),
  ('DTAP_4',  'DTaP 4차',              '생후 15~18개월',  15,  4, 28),
  ('HEPA_2',  'A형간염 2차',           '1차 후 6~12개월', 18,  2, 29),
  ('JE_3',    '일본뇌염(불활성화) 3차', '2차 후 12개월',  24,  3, 30)
on conflict (code) do nothing;


-- ============================================================================
-- 6. Storage 버킷
-- ============================================================================
-- 피부 사진 원본을 보관합니다.
-- 경로 규칙: {user_id}/{baby_id}/{파일명}  ← 첫 번째 폴더명으로 소유권을 판정합니다.

insert into storage.buckets (id, name, public) values
  ('skin-images', 'skin-images', false)
on conflict (id) do nothing;

-- 자기 폴더({user_id}/...) 안에서만 읽고 쓸 수 있습니다.
create policy storage_skin_own on storage.objects
  for all to authenticated
  using      (bucket_id = 'skin-images' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'skin-images' and (storage.foldername(name))[1] = auth.uid()::text);


-- ============================================================================
-- 7. 함께 키우기 (한 아이를 여러 보호자가 공유)
-- ============================================================================
-- owns_baby()가 이미 구성원 기준으로 정의되어 있습니다(4절).
-- 여기서는 구성원·초대 테이블과 관련 함수를 만듭니다.

-- ── 1. 구성원 테이블 ────────────────────────────────────────────────────────
-- ── 3. 새 아이를 만들면 자동으로 소유자 등록 ────────────────────────────────
-- 앱이 두 번 호출하도록 두면 한쪽만 성공했을 때 접근 불가 상태가 됩니다.
create or replace function public.handle_new_baby()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.baby_members (baby_id, user_id, role)
  values (new.id, new.user_id, 'owner')
  on conflict (baby_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_baby_created on public.babies;
create trigger on_baby_created
  after insert on public.babies
  for each row execute function public.handle_new_baby();


-- ── 6. baby_members 정책 ────────────────────────────────────────────────────
alter table public.baby_members enable row level security;

-- 같은 아이를 보는 사람끼리는 서로를 볼 수 있어야 목록을 만들 수 있습니다.
drop policy if exists baby_members_select on public.baby_members;
create policy baby_members_select on public.baby_members
  for select to authenticated
  using (public.owns_baby(baby_id));

-- 구성원 추가는 초대 수락 함수(security definer)로만 합니다.
-- 직접 insert를 허용하면 아무 아이에나 자신을 넣을 수 있습니다.

-- 나가기는 누구나 자기 행만. 소유자는 나갈 수 없습니다(아이가 주인 없이 남습니다).
drop policy if exists baby_members_leave on public.baby_members;
create policy baby_members_leave on public.baby_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    and role <> 'owner'
  );

-- 소유자는 다른 구성원을 내보낼 수 있습니다.
drop policy if exists baby_members_remove on public.baby_members;
create policy baby_members_remove on public.baby_members
  for delete to authenticated
  using (
    public.is_baby_owner(baby_id)
    and role <> 'owner'
  );


-- ── 7. 초대 ─────────────────────────────────────────────────────────────────
-- 이메일 발송 없이 코드를 불러주는 방식입니다. 상대의 계정을 몰라도 됩니다.
alter table public.baby_invites enable row level security;

-- 코드를 만든 쪽(구성원)만 자기 아이의 초대를 봅니다.
-- 초대받는 사람은 이 표를 직접 읽지 않습니다. 아래 수락 함수만 씁니다.
drop policy if exists baby_invites_select on public.baby_invites;
create policy baby_invites_select on public.baby_invites
  for select to authenticated
  using (public.owns_baby(baby_id));

drop policy if exists baby_invites_insert on public.baby_invites;
create policy baby_invites_insert on public.baby_invites
  for insert to authenticated
  with check (public.is_baby_owner(baby_id) and created_by = auth.uid());

drop policy if exists baby_invites_delete on public.baby_invites;
create policy baby_invites_delete on public.baby_invites
  for delete to authenticated
  using (public.is_baby_owner(baby_id));


-- ── 8. 초대 코드 만들기 ─────────────────────────────────────────────────────
create or replace function public.create_baby_invite(
  p_baby_id uuid,
  p_valid_days integer default 7
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- 0/O/1/I 제외
  i integer;
begin
  if not public.is_baby_owner(p_baby_id) then
    raise exception '초대 코드는 아이를 등록한 사람만 만들 수 있습니다.';
  end if;

  -- 충돌하면 다시 뽑습니다. 32^8이라 사실상 부딪히지 않지만 확인은 합니다.
  loop
    v_code := '';
    for i in 1..8 loop
      v_code := v_code || substr(v_alphabet, floor(random() * length(v_alphabet))::int + 1, 1);
    end loop;
    exit when not exists (select 1 from public.baby_invites where code = v_code);
  end loop;

  insert into public.baby_invites (code, baby_id, created_by, expires_at)
  values (v_code, p_baby_id, auth.uid(), now() + make_interval(days => p_valid_days));

  return v_code;
end;
$$;


-- ── 9. 초대 수락 ────────────────────────────────────────────────────────────
-- 초대받는 사람은 baby_invites를 읽을 권한이 없습니다. 이 함수가 유일한 문입니다.
create or replace function public.accept_baby_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.baby_invites;
begin
  select * into v_invite
  from public.baby_invites
  where code = upper(btrim(p_code))
  for update;

  if not found then
    raise exception '초대 코드를 찾을 수 없습니다.';
  end if;
  if v_invite.used_at is not null then
    raise exception '이미 사용된 초대 코드입니다.';
  end if;
  if v_invite.expires_at < now() then
    raise exception '만료된 초대 코드입니다.';
  end if;
  if exists (
    select 1 from public.baby_members
    where baby_id = v_invite.baby_id and user_id = auth.uid()
  ) then
    raise exception '이미 함께 보고 있는 아이입니다.';
  end if;

  insert into public.baby_members (baby_id, user_id, role)
  values (v_invite.baby_id, auth.uid(), 'member');

  update public.baby_invites
  set used_at = now(), used_by = auth.uid()
  where code = v_invite.code;

  return v_invite.baby_id;
end;
$$;


-- ── 10. 구성원 목록 (이름·이메일 포함) ──────────────────────────────────────
-- auth.users는 앱에서 직접 읽을 수 없으므로 함수로 필요한 것만 돌려줍니다.
create or replace function public.list_baby_members(p_baby_id uuid)
returns table (
  user_id   uuid,
  role      text,
  joined_at timestamptz,
  name      text,
  is_me     boolean
)
language sql
security definer
stable
set search_path = ''
as $$
  select
    m.user_id,
    m.role,
    m.joined_at,
    coalesce(p.name, split_part(u.email, '@', 1), '보호자') as name,
    m.user_id = auth.uid() as is_me
  from public.baby_members m
  join auth.users u on u.id = m.user_id
  left join public.profiles p on p.id = m.user_id
  where m.baby_id = p_baby_id
    and public.owns_baby(p_baby_id)   -- 구성원이 아니면 아무것도 돌려주지 않습니다
  order by (m.role = 'owner') desc, m.joined_at;
$$;

-- ============================================================================
-- 6. 마이그레이션에서 옮겨 온 표
-- ============================================================================
-- 이 파일 하나로 새 DB를 만들 수 있어야 하므로, 나중에 추가된 표도 여기에
-- 함께 둡니다. 이미 돌아가는 DB에는 supabase/migrations/의 해당 파일을
-- 실행하세요(이 절과 같은 내용입니다).
--
-- 앞 절에서 owns_baby()가 이미 정의돼 있어야 하므로 맨 뒤에 둡니다.


-- ── 6.1 커뮤니티 (migrations/003) ───────────────────────────────────────────
-- ⚠️ 이 두 표는 다른 표와 RLS 방향이 반대입니다. 육아 기록은 "본인 것만
--    읽기"이지만, 커뮤니티는 "모두 읽기 · 본인 것만 쓰기"입니다.

-- 1. 게시글 ------------------------------------------------------------------
create table if not exists public.posts (
  id          uuid        primary key default gen_random_uuid(),
  author_id   uuid        not null references auth.users (id) on delete cascade,
  title       text        not null check (char_length(btrim(title)) between 1 and 100),
  body        text        not null check (char_length(btrim(body)) between 1 and 2000),
  -- 갈래는 앱의 기록 기능과 맞춥니다. enum이 아니라 CHECK인 이유는 다른 표와
  -- 같습니다 — 갈래를 늘릴 때 ALTER TABLE 하나면 됩니다.
  category    text        not null default 'etc'
    check (category in ('feeding', 'sleep', 'diaper', 'health', 'growth', 'etc')),
  created_at  timestamptz not null default now()
);

comment on table  public.posts           is '커뮤니티 게시글. 작성자는 화면에서 익명으로 표시된다';
comment on column public.posts.author_id is '수정·삭제 권한 확인용. 화면에는 노출하지 않는다';
comment on column public.posts.category  is 'feeding=수유, sleep=수면(소음 포함), diaper=배변, health=체온·약·병원·예방접종·피부, growth=성장, etc=그 밖에';

-- 2. 댓글 --------------------------------------------------------------------
create table if not exists public.comments (
  id          uuid        primary key default gen_random_uuid(),
  post_id     uuid        not null references public.posts (id) on delete cascade,
  author_id   uuid        not null references auth.users (id) on delete cascade,
  body        text        not null check (char_length(btrim(body)) between 1 and 500),
  created_at  timestamptz not null default now()
);

-- 3. 인덱스 ------------------------------------------------------------------
-- 목록은 최신순, 댓글은 오래된 순으로 봅니다.
create index if not exists idx_posts_created     on public.posts    (created_at desc);
create index if not exists idx_posts_category    on public.posts    (category, created_at desc);
create index if not exists idx_comments_post     on public.comments (post_id, created_at);
create index if not exists idx_posts_author      on public.posts    (author_id);
create index if not exists idx_comments_author   on public.comments (author_id);

-- 4. RLS ---------------------------------------------------------------------
alter table public.posts    enable row level security;
alter table public.comments enable row level security;

-- 읽기는 로그인한 사용자 전체에게 엽니다.
drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts
  for select to authenticated
  using (true);

drop policy if exists comments_read on public.comments;
create policy comments_read on public.comments
  for select to authenticated
  using (true);

-- 쓰기·수정·삭제는 작성자 본인만.
-- with check 를 빠뜨리면 남의 이름으로 글을 쓸 수 있습니다.
drop policy if exists posts_insert on public.posts;
create policy posts_insert on public.posts
  for insert to authenticated
  with check (auth.uid() = author_id);

drop policy if exists posts_update on public.posts;
create policy posts_update on public.posts
  for update to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

drop policy if exists posts_delete on public.posts;
create policy posts_delete on public.posts
  for delete to authenticated
  using (auth.uid() = author_id);

drop policy if exists comments_insert on public.comments;
create policy comments_insert on public.comments
  for insert to authenticated
  with check (auth.uid() = author_id);

drop policy if exists comments_update on public.comments;
create policy comments_update on public.comments
  for update to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

drop policy if exists comments_delete on public.comments;
create policy comments_delete on public.comments
  for delete to authenticated
  using (auth.uid() = author_id);


-- ── 6.2 약 복용 · 병원 방문 (migrations/006) ────────────────────────────────

-- ── 1. 약 복용 ──────────────────────────────────────────────────────────────
create table public.medication_records (
  id         uuid        primary key default gen_random_uuid(),
  baby_id    uuid        not null references public.babies (id) on delete cascade,

  -- 약 이름. 처방약 이름은 종류가 끝이 없어 고정 목록을 만들 수 없습니다.
  name       text        not null check (length(trim(name)) between 1 and 100),

  -- 용량. 'ml', '포', '알'처럼 단위가 제각각이라 숫자로 쪼개지 않습니다.
  dose       text        check (length(dose) <= 50),

  -- 왜 먹였는가. 반복 여부를 세는 기준입니다.
  reason     text        not null check (reason in (
                 'fever', 'cough', 'runny_nose', 'rash', 'vomit',
                 'diarrhea', 'prescription', 'other')),

  taken_at   timestamptz not null,
  created_at timestamptz not null default now()
);

comment on column public.medication_records.reason is
  'fever=발열, cough=기침, runny_nose=콧물, rash=발진, vomit=구토, diarrhea=설사, prescription=처방약 복용, other=기타';

create index medication_records_baby_taken_idx
  on public.medication_records (baby_id, taken_at desc);


-- ── 2. 병원 방문 ────────────────────────────────────────────────────────────
create table public.hospital_visits (
  id            uuid        primary key default gen_random_uuid(),
  baby_id       uuid        not null references public.babies (id) on delete cascade,

  hospital_name text        check (length(hospital_name) <= 100),

  reason        text        not null check (reason in (
                    'fever', 'cough', 'runny_nose', 'rash', 'vomit',
                    'diarrhea', 'checkup', 'vaccination', 'other')),

  -- 진료실에서 들은 이야기를 보호자가 적는 칸입니다.
  -- `diagnosis`라 부르지 않는 이유는, 이 앱이 진단을 다룬다는 인상을 주지
  -- 않기 위해서입니다. 이 앱은 의료기기가 아닙니다.
  note          text        check (length(note) <= 500),

  visited_at    timestamptz not null,
  created_at    timestamptz not null default now()
);

comment on column public.hospital_visits.reason is
  'fever=발열, cough=기침, runny_nose=콧물, rash=발진, vomit=구토, diarrhea=설사, checkup=정기검진, vaccination=예방접종, other=기타';
comment on column public.hospital_visits.note is
  '보호자가 적는 진료 메모. 앱이 만들어 내는 진단이 아닙니다.';

create index hospital_visits_baby_visited_idx
  on public.hospital_visits (baby_id, visited_at desc);


-- ── 3. RLS ──────────────────────────────────────────────────────────────────
-- 다른 기록 표와 같습니다. owns_baby() 하나가 판정 근거이므로, 함께 키우기로
-- 초대받은 구성원도 같은 규칙으로 보고 씁니다.
alter table public.medication_records enable row level security;
alter table public.hospital_visits    enable row level security;

create policy medication_own on public.medication_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

create policy hospital_visit_own on public.hospital_visits
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));
