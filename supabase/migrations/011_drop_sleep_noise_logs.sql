-- 011. 소음 원시 로그를 버린다
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
-- **소음 수치는 이제 어디에도 따로 저장하지 않는다.** 재는 동안에는 화면에
-- 실시간으로 보여주고, 끝나면 앱이 메모리에서 집계해 판정을 만든다. 그
-- 숫자가 남는 곳은 판정 한 행뿐이다 — assessments.inputs의
-- average_db / max_db / sample_count. 분석 화면이 지난 밤을 보여줄 때 읽는
-- 것도 그 판정이다.
--
-- (한때 sleep_records에 같은 세 값을 적어 두려 했다. 판정이 이미 들고 있어
--  중복이었다.)
--
-- 다시 돌려도 된다.

-- 009에서 만든 집계 함수. 읽을 로그가 없어지므로 함께 지운다.
drop function if exists public.sleep_noise_stats(uuid);

drop table if exists public.sleep_noise_logs cascade;

-- 이 함수를 쓰던 정책은 sleep_noise_logs의 것 하나뿐이었다. 표가 사라지면
-- 함수도 쓰이지 않는다. (owns_temp_record는 남는다 — temperature_symptoms가
-- 여전히 쓴다.)
drop function if exists public.owns_sleep_record(uuid);
