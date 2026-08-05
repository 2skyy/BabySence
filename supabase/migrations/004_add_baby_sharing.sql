-- ============================================================================
-- 004. 함께 키우기 (한 아이를 여러 보호자가 공유)
--
-- schema.sql을 이미 실행한 DB에 이 파일을 실행하세요.
-- 여러 번 실행해도 안전합니다.
--
-- 【핵심】 owns_baby() 함수 하나만 바꾸면 기록 테이블 18개 정책이 전부
--        공유를 따릅니다. 각 정책을 고칠 필요가 없습니다.
--
--        기존:  babies.user_id = auth.uid()          (혼자만)
--        변경:  baby_members에 내 행이 있는가          (공유)
-- ============================================================================


-- ── 1. 구성원 테이블 ────────────────────────────────────────────────────────
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


-- ── 2. 기존 아이를 소유자 구성원으로 옮기기 ─────────────────────────────────
-- 이 작업 전에 만들어진 아이들은 babies.user_id에만 보호자가 있습니다.
-- 옮기지 않으면 만든 사람조차 자기 아이를 못 보게 됩니다.
insert into public.baby_members (baby_id, user_id, role)
select b.id, b.user_id, 'owner'
from public.babies b
on conflict (baby_id, user_id) do nothing;


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


-- ── 4. 소유권 판정을 구성원 기준으로 교체 ───────────────────────────────────
-- security definer라 이 함수 안의 조회는 RLS를 거치지 않습니다.
-- 덕분에 baby_members 정책이 다시 이 함수를 부르는 순환이 생기지 않습니다.
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


-- ── 5. babies 정책을 구성원 기준으로 ────────────────────────────────────────
-- 기존 정책은 만든 사람만 볼 수 있어, 초대받은 사람이 아이를 못 봅니다.
drop policy if exists babies_own on public.babies;

create policy babies_select on public.babies
  for select to authenticated
  using (public.owns_baby(id));

-- 새 아이는 자기 이름으로만 만들 수 있습니다.
create policy babies_insert on public.babies
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy babies_update on public.babies
  for update to authenticated
  using (public.owns_baby(id))
  with check (public.owns_baby(id));

-- 아이 삭제는 되돌릴 수 없고 기록이 전부 사라지므로 소유자만 할 수 있습니다.
create policy babies_delete on public.babies
  for delete to authenticated
  using (public.is_baby_owner(id));


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
