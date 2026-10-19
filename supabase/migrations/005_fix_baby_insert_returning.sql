-- 005: 아이 등록이 실패하던 문제
--
-- ## 증상
--
-- 온보딩에서 아이 정보를 저장하면 이렇게 실패합니다.
--
--   new row violates row-level security policy for table "babies"
--
-- ## 원인
--
-- 앱은 `.insert(...).select().single()`을 씁니다. PostgREST는 이것을
-- `INSERT ... RETURNING *`으로 보냅니다.
--
-- PostgreSQL은 RETURNING으로 나가는 행에 **SELECT 정책**을 적용합니다.
-- 그런데 004의 SELECT 정책은 `owns_baby(id)`, 즉 `baby_members`에 행이
-- 있는지를 봅니다. 그 행을 넣어 주는 `on_baby_created`는 **AFTER INSERT**
-- 트리거라 문장이 끝날 때 실행됩니다.
--
--   INSERT 실행 → RETURNING 평가(정책 검사) → AFTER 트리거 실행
--                        ↑ 여기서 baby_members가 아직 비어 있음
--
-- 그래서 방금 자기가 만든 아이인데도 못 읽고 통째로 실패합니다.
--
-- BEFORE 트리거로 옮기는 방법은 쓸 수 없습니다. `baby_members.baby_id`가
-- `babies(id)`를 참조하므로, 부모 행이 들어가기 전에 자식을 넣으면 외래 키
-- 위반입니다.
--
-- ## 고침
--
-- 만든 사람은 `baby_members`와 무관하게 자기 아이를 볼 수 있게 합니다.
-- 트리거가 어떤 이유로 실패해도 자기 아이를 잃지 않는다는 뜻이기도 합니다.
--
-- 초대받은 구성원은 `owns_baby(id)` 쪽으로 계속 통과하므로 공유는 그대로입니다.
-- INSERT/UPDATE/DELETE 정책은 004 그대로 두므로, 남의 이름으로 아이를 만들거나
-- 남의 아이를 지우는 것은 여전히 막힙니다.

drop policy if exists babies_select on public.babies;

create policy babies_select on public.babies
  for select to authenticated
  using (public.owns_baby(id) or user_id = auth.uid());
