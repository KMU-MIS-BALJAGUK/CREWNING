-- 2025-11-03: change register.user_id to text so UUID strings can be inserted
-- 안전하게 컬럼이 존재하지 않으면 생성하고, 존재하지만 타입이 text가 아니면 text로 변환합니다.
-- Supabase SQL Editor에 붙여넣고 실행하세요.

BEGIN;

-- 컬럼이 없으면 text로 생성
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'register' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE public.register ADD COLUMN user_id text;
  END IF;
END$$;

-- 컬럼이 존재하지만 text가 아니면 text로 타입 변경 (안전한 USING 캐스트)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'register' AND column_name = 'user_id' AND data_type <> 'text'
  ) THEN
    ALTER TABLE public.register ALTER COLUMN user_id TYPE text USING user_id::text;
  END IF;
END$$;

COMMIT;

-- 주의: 이 스크립트는 기존 정수값 등을 text로 바꿉니다.
-- 나중에 이 컬럼을 엄격히 uuid 타입으로 바꾸고 싶다면, 모든 값이 UUID 포맷으로 바뀐 이후에 아래 명령으로 변경하세요:
-- ALTER TABLE public.register ALTER COLUMN user_id TYPE uuid USING user_id::uuid;
