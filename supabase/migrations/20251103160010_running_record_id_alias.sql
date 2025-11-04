DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'running_record'
      AND column_name = 'id'
  ) THEN
    EXECUTE 'ALTER TABLE public."running_record" ADD COLUMN id integer GENERATED ALWAYS AS (record_id) STORED';
  END IF;
END;
$$;

COMMENT ON COLUMN public."running_record".id IS 'Legacy compatibility alias for record_id';
