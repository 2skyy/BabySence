-- 012. 앱이 그리는 콘텐츠(공지사항·육아 가이드)를 표로
--
-- '전체' 탭의 공지사항·육아 가이드는 콘텐츠를 넣고 고칠 수단이 없어
-- '준비 중'으로 남아 있었다. 화면을 만들 손이 없어서가 아니라, 글이
-- 바뀔 때마다 코드를 고쳐 **스토어 심사를 다시 받아야 하는 구조**가
-- 병목이었다.
--
-- 그래서 콘텐츠를 코드가 아니라 데이터로 둔다. blocks에 블록 배열
-- [{"type": "heading", "props": {...}}, ...]을 담고, 앱의 블록 렌더러가
-- type→위젯으로 옮겨 그린다. 글을 바꾸는 일은 행을 바꾸는 일이 되고,
-- 이미 설치된 앱에 심사 없이 반영된다.
--
-- 블록 type은 앱에 등록된 것만 그려진다(heading·paragraph·alert·image).
-- 모르는 type은 앱이 조용히 건너뛰므로, 새 type을 쓰는 콘텐츠를 먼저
-- 발행해도 구버전 앱이 죽지 않는다 — 그 블록만 안 보일 뿐이다.
--
-- 쓰기 정책은 만들지 않는다. 발행·수정은 운영자가 SQL로 직접 한다.
-- 에디터까지 만드는 것은 지금 규모에 과하다.
--
-- 다시 돌려도 된다.

create table if not exists public.contents (
  id           uuid        primary key default gen_random_uuid(),
  category     text        not null check (category in ('notice', 'guide')),
  title        text        not null check (char_length(title) between 1 and 200),
  blocks       jsonb       not null default '[]'::jsonb,
  -- NULL이면 아직 발행 전(초안). 앱은 발행된 것만 읽는다.
  published_at timestamptz,
  created_at   timestamptz not null default now()
);

comment on table  public.contents          is '앱이 그리는 콘텐츠. blocks의 블록 배열을 앱의 렌더러가 위젯으로 옮긴다';
comment on column public.contents.category is 'notice=공지사항, guide=육아 가이드';
comment on column public.contents.blocks   is '[{"type": "...", "props": {...}}] — type은 앱에 등록된 것만 그려지고, 모르는 type은 건너뛴다';

alter table public.contents enable row level security;

-- 읽기 전용. 아이 소유와 무관한 전체 공지라 owns_baby를 지나지 않는다.
-- 발행 전(초안)은 클라이언트에 보이지 않는다 — 쿼리가 아니라 정책으로
-- 막아야, 앱이 조건을 빠뜨려도 초안이 새지 않는다.
drop policy if exists contents_read on public.contents;
create policy contents_read on public.contents
  for select to authenticated
  using (published_at is not null and published_at <= now());

create index if not exists idx_contents_category
  on public.contents (category, published_at desc);
