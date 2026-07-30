-- ============================================================================
-- 001. assessments 테이블 추가
--
-- schema.sql을 이미 실행한 DB에 이 파일만 추가로 실행하면 됩니다.
-- (DB를 새로 만드는 경우에는 schema.sql에 이미 포함되어 있으므로 불필요)
--
-- 규칙 엔진의 '정상 / 주의 / 상담 권장' 3단계 판정과 행동 가이드를 보관합니다.
-- ============================================================================

create table if not exists public.assessments (
  id            uuid        primary key default gen_random_uuid(),
  baby_id       uuid        not null references public.babies (id) on delete cascade,
  domain        text        not null check (domain in (
                              'temperature', 'feeding', 'sleep', 'diaper',
                              'growth', 'noise', 'skin', 'overall')),
  level         text        not null check (level in ('normal', 'caution', 'consult')),
  guide_text    text        not null,
  inputs        jsonb       not null,
  rule_version  text        not null,
  assessed_at   timestamptz not null default now()
);

comment on column public.assessments.level        is 'normal=정상, caution=주의, consult=상담 권장';
comment on column public.assessments.guide_text   is '판정에 대응하는 행동 가이드 문장';
comment on column public.assessments.inputs       is '판정 시점의 입력값 스냅샷. 원본 기록이 수정되어도 판정 이력이 보존된다';
comment on column public.assessments.rule_version is '적용된 임계값 규칙의 버전. 판단 근거의 추적에 사용';

create index if not exists idx_assessments_baby_time
  on public.assessments (baby_id, assessed_at desc);

alter table public.assessments enable row level security;

drop policy if exists assessments_own on public.assessments;
create policy assessments_own on public.assessments
  for all to authenticated
  using (public.owns_baby(baby_id))
  with check (public.owns_baby(baby_id));
