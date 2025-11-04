DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'running_record'
      AND column_name = 'start_area_id'
  ) THEN
    ALTER TABLE public."running_record"
      ADD COLUMN start_area_id integer;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'running_record'
      AND column_name = 'start_area_name'
  ) THEN
    ALTER TABLE public."running_record"
      ADD COLUMN start_area_name text;
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'running_record'
      AND column_name = 'start_area_id'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'running_record'
      AND tc.constraint_name = 'running_record_start_area_id_fkey'
  ) THEN
    ALTER TABLE public."running_record"
      ADD CONSTRAINT running_record_start_area_id_fkey
      FOREIGN KEY (start_area_id) REFERENCES public."area"(area_id) ON DELETE SET NULL;
  END IF;
END;
$$;
