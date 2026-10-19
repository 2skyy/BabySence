-- 007. 커뮤니티 글에 분류를 붙입니다.
--
-- 글이 한 줄로 쌓이면 수유 이야기와 예방접종 이야기가 섞여, 지금 궁금한
-- 것만 골라 볼 수가 없습니다. 앱의 기록 기능과 같은 갈래로 나눕니다.
--
-- 갈래를 여섯으로 줄인 이유: 기록 기능은 아홉인데 그대로 옮기면 빈 방이
-- 여럿 생깁니다. 함께 이야기되는 것끼리 묶었습니다.
--   health = 체온 · 약/병원 · 예방접종 · 피부
--   sleep  = 수면 · 수면 환경 소음
--
-- 값을 CHECK로 두는 이유는 다른 표와 같습니다 — enum은
-- `ALTER TYPE ... ADD VALUE`가 트랜잭션 안에서 실행되지 않아 갈래를 늘릴 때
-- 까다롭지만, CHECK는 `ALTER TABLE`로 갈아끼우면 됩니다.

alter table public.posts
  add column if not exists category text not null default 'etc';

alter table public.posts
  drop constraint if exists posts_category_check;

alter table public.posts
  add constraint posts_category_check
  check (category in ('feeding', 'sleep', 'diaper', 'health', 'growth', 'etc'));

comment on column public.posts.category is
  'feeding=수유, sleep=수면(소음 포함), diaper=배변, health=체온·약·병원·예방접종·피부, growth=성장, etc=그 밖에';

-- 목록은 갈래별 최신순으로 봅니다. created_at 단독 인덱스는 '전체' 탭이
-- 계속 쓰므로 그대로 둡니다.
create index if not exists idx_posts_category
  on public.posts (category, created_at desc);
