-- 006: 약 복용 · 병원 방문 기록
--
-- 논문 3-2절 ⑥ "약 복용 정보와 병원 방문 기록을 저장하고, 이를 기반으로
-- 반복적인 증상 발생 여부를 확인한다."
--
-- ## 판정하지 않습니다
--
-- 이 두 표는 **저장과 집계만** 합니다. 며칠 안에 몇 번이면 이상인지에 대한
-- 기준이 어느 출처에도 없어서, 정상/주의/상담 권장을 매기지 않습니다.
-- 화면은 "지난 90일 동안 '구토'로 2번" 처럼 **센 값만** 보여줍니다.
--
-- ## 사유를 자유 입력으로 두지 않은 이유
--
-- 논문이 요구하는 "반복적인 증상 발생 여부"를 세려면 같은 증상이 같은 값으로
-- 저장돼야 합니다. '토함' / '구토' / '토' 를 각각 적으면 셀 수 없습니다.
-- 그래서 사유는 고정 목록이고, 목록에 없는 것은 'other' + 메모로 남깁니다.

-- ── 1. 약 복용 ──────────────────────────────────────────────────────────────
create table if not exists public.medication_records (
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

create index if not exists medication_records_baby_taken_idx
  on public.medication_records (baby_id, taken_at desc);


-- ── 2. 병원 방문 ────────────────────────────────────────────────────────────
create table if not exists public.hospital_visits (
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

create index if not exists hospital_visits_baby_visited_idx
  on public.hospital_visits (baby_id, visited_at desc);


-- ── 3. RLS ──────────────────────────────────────────────────────────────────
-- 중간에 실패해도 그대로 다시 붙여넣을 수 있게 전부 되풀이해도 되는 형태로
-- 씁니다(if not exists / drop policy if exists).
-- 다른 기록 표와 같습니다. owns_baby() 하나가 판정 근거이므로, 함께 키우기로
-- 초대받은 구성원도 같은 규칙으로 보고 씁니다.
alter table public.medication_records enable row level security;
alter table public.hospital_visits    enable row level security;

drop policy if exists medication_own on public.medication_records;
create policy medication_own on public.medication_records
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));

drop policy if exists hospital_visit_own on public.hospital_visits;
create policy hospital_visit_own on public.hospital_visits
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));
