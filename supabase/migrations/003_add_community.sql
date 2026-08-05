-- ============================================================================
-- 003. 커뮤니티(게시글 · 댓글) 추가
--
-- schema.sql을 이미 실행한 DB에 이 파일을 실행하세요.
-- 여러 번 실행해도 안전합니다.
--
-- ⚠️ 이 두 테이블은 다른 테이블과 RLS 방향이 반대입니다.
--    육아 기록은 "본인 것만 읽기"이지만, 커뮤니티는 "모두 읽기 · 본인 것만 쓰기"입니다.
--    공유가 목적인 데이터라 읽기를 막으면 기능 자체가 성립하지 않습니다.
-- ============================================================================

-- 1. 게시글 ------------------------------------------------------------------
create table if not exists public.posts (
  id          uuid        primary key default gen_random_uuid(),
  author_id   uuid        not null references auth.users (id) on delete cascade,
  title       text        not null check (char_length(btrim(title)) between 1 and 100),
  body        text        not null check (char_length(btrim(body)) between 1 and 2000),
  created_at  timestamptz not null default now()
);

comment on table  public.posts           is '커뮤니티 게시글. 작성자는 화면에서 익명으로 표시된다';
comment on column public.posts.author_id is '수정·삭제 권한 확인용. 화면에는 노출하지 않는다';

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
