-- 2025-11-03: allow authenticated users to INSERT into public.register
-- Supabase SQL Editor에 붙여넣고 실행하세요.

BEGIN;

-- RLS가 활성화되어 있지 않으면 활성화 (이미 활성화되어 있으면 영향 없음)
ALTER TABLE IF EXISTS public.register ENABLE ROW LEVEL SECURITY;

-- 기존 같은 이름의 정책이 있으면 제거
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies p WHERE p.schemaname = 'public' AND p.tablename = 'register' AND p.policyname = 'allow_authenticated_insert_register'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS allow_authenticated_insert_register ON public.register';
  END IF;
END$$;

-- 인증된 사용자가 자신의 로컬 user.user_id에 해당하는 user_id로만 INSERT 할 수 있도록 허용
CREATE POLICY allow_authenticated_insert_register
  ON public.register
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."user" u
      WHERE u.user_id = user_id AND u.auth_user_id::text = auth.uid()::text
    )
  );

COMMIT;

-- 설명:
-- 이 정책은 사용자가 INSERT할 때 새 행(user_id)이 현재 로그인한 auth.uid()에 연결된 로컬 user.user_id와 일치할 때만 허용합니다.
-- SQL Editor에서 실행한 후 앱에서 다시 신청을 시도해 보세요.
