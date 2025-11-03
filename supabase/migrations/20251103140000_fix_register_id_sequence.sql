-- 2025-11-03: fix register.register_id sequence/default
-- 1) 시퀀스가 없으면 생성
-- 2) 시퀀스 소유자 설정
-- 3) 컬럼 DEFAULT를 nextval(...)으로 설정
-- 4) 기존 NULL 값을 시퀀스 값으로 채움
-- 5) NOT NULL로 변경
-- 6) PRIMARY KEY가 없으면 추가

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'S' AND n.nspname = 'public' AND c.relname = 'register_register_id_seq'
  ) THEN
    CREATE SEQUENCE public.register_register_id_seq;
  END IF;
END$$;

ALTER SEQUENCE public.register_register_id_seq OWNED BY public.register.register_id;

-- 컬럼에 DEFAULT가 없으면 설정
ALTER TABLE public.register ALTER COLUMN register_id SET DEFAULT nextval('public.register_register_id_seq');

-- 시퀀스 값을 현재 최대값 기반으로 조정 (중복 방지)
SELECT setval('public.register_register_id_seq', COALESCE((SELECT MAX(register_id) FROM public.register), 0) + 1, false);

-- 기존 NULL인 register_id를 시퀀스로 채움
UPDATE public.register SET register_id = nextval('public.register_register_id_seq') WHERE register_id IS NULL;

-- NOT NULL로 변경
ALTER TABLE public.register ALTER COLUMN register_id SET NOT NULL;

-- PRIMARY KEY가 없으면 추가 (안전하게 존재 여부 체크)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public' AND tc.table_name = 'register' AND tc.constraint_type = 'PRIMARY KEY'
  ) THEN
    ALTER TABLE public.register ADD PRIMARY KEY (register_id);
  END IF;
END$$;

COMMIT;

-- 실행 후: INSERT 시 register_id를 지정하지 않아도 자동으로 증가값이 들어갑니다.
-- 문제가 발생하면 에러 메시지를 복사해 주세요.
