-- ============================================================================
-- 002. 울음소리 분석 제거
--
-- 울음소리 분석 기능을 프로젝트 범위에서 제외하기로 결정하여
-- 관련 테이블과 Storage 버킷을 삭제합니다.
--
-- schema.sql을 이미 실행한 DB에 이 파일을 실행하세요.
-- 001을 아직 실행하지 않았다면 001 → 002 순서로 실행하면 됩니다.
-- 여러 번 실행해도 안전합니다.
-- ============================================================================

-- 1. cry_analyses 테이블 (정책·인덱스는 테이블과 함께 사라집니다)
drop table if exists public.cry_analyses cascade;

-- 2. Storage 접근 정책
--
--    버킷 자체는 SQL로 지울 수 없습니다. Supabase가 storage.protect_delete()
--    트리거로 storage.buckets / storage.objects 직접 삭제를 차단하기 때문입니다.
--    (ERROR 42501: Direct deletion from storage tables is not allowed)
--
--    'cry-audio' 버킷은 대시보드에서 지우세요.
--      Storage -> cry-audio -> 우측 상단 ... -> Delete bucket
--
--    아래 정책 삭제만으로도 버킷에 접근할 수 없게 되므로, 버킷 제거는
--    정리 목적입니다.
drop policy if exists storage_cry_own on storage.objects;

-- 3. assessments.domain 에서 'cry' 제거
--    001을 'cry'가 포함된 버전으로 이미 실행했을 경우를 위한 처리입니다.
--    assessments 테이블이 아직 없으면 아무것도 하지 않습니다.
do $$
begin
  if exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'assessments') then
    alter table public.assessments drop constraint if exists assessments_domain_check;
    alter table public.assessments add constraint assessments_domain_check
      check (domain in ('temperature', 'feeding', 'sleep', 'diaper',
                        'growth', 'noise', 'skin', 'overall'));
  end if;
end $$;
