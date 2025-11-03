-- 2025-11-03: add message column to public.register (optional applicant message)
-- Supabase SQL Editor에 붙여넣고 실행하세요.

BEGIN;

ALTER TABLE public.register
  ADD COLUMN IF NOT EXISTS message text;

COMMIT;

-- 이후 클라이언트에서 INSERT 시 'message' 필드를 사용하실 수 있습니다.
