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

-- 2. Storage 버킷과 접근 정책
drop policy if exists storage_cry_own on storage.objects;
delete from storage.objects where bucket_id = 'cry-audio';
delete from storage.buckets where id = 'cry-audio';

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
