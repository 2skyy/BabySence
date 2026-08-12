-- 011. 소음 원시 로그를 버리고 집계만 남긴다
--
-- sleep_noise_logs에는 1초마다 한 행이 쌓였다. 하룻밤이면 28,800행이다.
-- 그런데 **그 로그를 읽는 곳은 평균·최대를 구하는 집계 함수 하나뿐**이었고,
-- 인덱스 주석이 근거로 든 "그래프 조회용" 화면은 만든 적이 없다.
--
-- 원본을 서버까지 나르려고 붙은 장치들이 이 기능의 결함을 만들었다.
--   · 행 상한에 잘려 밤 통계가 '측정 직후 몇 분'이 됐던 것 (009 이전)
--   · 004가 2단계 RLS를 놓쳐 밤새 재고도 0건이던 것 (008에서 수정)
--   · 밤새 망이 끊기면 8시간을 재고도 결과가 안 나오던 것
--
-- 이제 앱이 메모리에서 집계하고 60초마다 이 세 컬럼을 갱신한다. 판정
-- 경로에서 네트워크가 통째로 빠지고, 잃을 수 있는 것은 최대 60초다.
--
-- **파생 데이터를 저장하는 것 아닌가?** 아니다. 로그가 사라지면 이 세 값은
-- 무엇으로도 다시 만들 수 없다. 파생값이 아니라 **원본**이다. 수면 시간을
-- 저장하지 않는 것(started_at/ended_at으로 계산 가능)과는 경우가 다르다.
--
-- 다시 돌려도 되게 만들었다.

alter table public.sleep_records
  add column if not exists average_db   numeric(5,2) not null default 0,
  add column if not exists max_db       numeric(5,2) not null default 0,
  add column if not exists sample_count integer      not null default 0;

alter table public.sleep_records
  drop constraint if exists sleep_records_noise_range_check;

alter table public.sleep_records
  add constraint sleep_records_noise_range_check
  check (
    average_db   between 0 and 200 and
    max_db       between 0 and 200 and
    sample_count >= 0
  );

comment on column public.sleep_records.average_db is
  '구간 평균 데시벨(WHO LAeq 대응). 1초 창 최댓값들의 평균이다';
comment on column public.sleep_records.max_db is
  '구간 최대 데시벨(WHO LAmax 대응)';
comment on column public.sleep_records.sample_count is
  '1초 창 표본 수. 판정에 필요한 최소 표본을 확인하는 데 쓴다';

-- 009에서 만든 집계 함수. 읽을 로그가 없어지므로 함께 지운다.
drop function if exists public.sleep_noise_stats(uuid);

drop table if exists public.sleep_noise_logs cascade;

-- 이 함수를 쓰던 정책은 sleep_noise_logs의 것 하나뿐이었다. 표가 사라지면
-- 함수도 쓰이지 않는다. (owns_temp_record는 남는다 — temperature_symptoms가
-- 여전히 쓴다.)
drop function if exists public.owns_sleep_record(uuid);
