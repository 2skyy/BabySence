-- 009. 소음 통계를 DB에서 집계합니다.
--
-- ## 무엇이 잘못돼 있었나
--
-- `loadNoiseStats`가 한 수면 구간의 로그를 **limit도 order도 없이** 전부
-- 받아 와 앱에서 평균·최대를 냈습니다.
--
--   select decibel from sleep_noise_logs where sleep_record_id = ...
--
-- 로그는 오디오 콜백마다 한 줄씩 쌓입니다. 하룻밤이면 수만 행이 됩니다.
-- PostgREST는 `db-max-rows` 설정이 있으면 그 수만큼만 돌려주는데, `order`가
-- 없으니 **어느 구간이 잘렸는지도 알 수 없습니다.** 실제로는 대개 먼저 들어간
-- 행부터 돌아오므로, 밤새 잰 결과가 **측정 시작 직후 몇 분**의 통계가 됩니다.
-- 그리고 그 통계로 만든 판정이 `assessments`에 그대로 저장됩니다.
--
-- 설정이 없다면 반대로 수만 행을 전부 내려받아 느려집니다. 어느 쪽이든
-- 앱에서 셀 일이 아닙니다.
--
-- ## security invoker인 이유
--
-- 부르는 사람의 권한으로 돌아야 `sleep_noise_logs`의 RLS(noise_own →
-- owns_sleep_record → owns_baby)가 그대로 걸립니다. definer로 두면 남의 아이
-- 통계도 계산해 줍니다.

create or replace function public.sleep_noise_stats(p_sleep_record_id uuid)
returns table (
  average_db   double precision,
  max_db       double precision,
  sample_count bigint
)
language sql
security invoker
stable
set search_path = ''
as $$
  select
    coalesce(avg(l.decibel), 0)::double precision,
    coalesce(max(l.decibel), 0)::double precision,
    count(*)
  from public.sleep_noise_logs l
  where l.sleep_record_id = p_sleep_record_id;
$$;

comment on function public.sleep_noise_stats(uuid) is
  '한 수면 구간의 소음 평균·최대·표본 수. 앱이 수만 행을 내려받지 않도록 DB에서 집계한다';
