-- 008. 두 단계를 거치는 소유 확인 함수도 함께 키우기를 따르게 합니다.
--
-- ## 무엇이 잘못돼 있었나
--
-- 004가 `owns_baby()`를 "소유자 또는 초대받은 구성원"으로 바꿨지만,
-- `owns_sleep_record()`와 `owns_temp_record()`는 그대로 남았습니다.
-- 이 둘은 아직 `b.user_id = auth.uid()` — **소유자만** 봅니다.
--
-- 이 함수를 쓰는 정책이 둘입니다.
--   sleep_noise_logs.noise_own          → owns_sleep_record()
--   temperature_symptoms.temperature_symptoms_own → owns_temp_record()
--
-- 그래서 초대받은 보호자에게는 이런 일이 벌어집니다.
--
-- - **체온 증상이 조용히 사라집니다.** 읽기가 막혀 빈 배열이 오는데, 앱은
--   그것을 "증상 없음"과 구별하지 못합니다. 열이 나면서 기침하던 아이가
--   증상 없는 발열로 보입니다.
-- - **증상 저장이 매번 실패합니다.** 체온 저장은 2단계(기록 → 증상)인데
--   2단계가 RLS에 막힙니다. 화면은 실패라고 하고 사용자는 다시 누르므로
--   체온 행만 중복으로 쌓입니다.
-- - **소음 로그가 한 건도 저장되지 않습니다.** 밤새 재도 표본이 0이라
--   "측정 시간이 짧습니다"로 끝납니다.
--
-- ## 왜 004가 놓쳤나
--
-- 004는 "함수 하나만 바꾸면 정책 16개가 따라온다"는 설계였는데, 이 둘은
-- `owns_baby()`를 부르지 않고 `babies`를 직접 조인했습니다. 한 다리 건너
-- 있어서 교체 대상에서 빠졌습니다.

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

comment on function public.owns_sleep_record(uuid) is
  '수면 기록의 아이를 볼 수 있는지. owns_baby를 경유하므로 함께 키우기를 따른다';
comment on function public.owns_temp_record(uuid) is
  '체온 기록의 아이를 볼 수 있는지. owns_baby를 경유하므로 함께 키우기를 따른다';
