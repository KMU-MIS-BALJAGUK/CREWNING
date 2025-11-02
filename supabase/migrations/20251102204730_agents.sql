-- Weekly reset helper function
CREATE OR REPLACE FUNCTION public.reset_weekly_scores()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  UPDATE public."user" SET weekly_score = 0;
$$;

-- Cron job to run every Monday at 00:00 KST (Sun 15:00 UTC)
SELECT
  cron.schedule(
    'reset-weekly-user-scores',
    '0 15 * * 0',
    $$SELECT public.reset_weekly_scores();$$
  )
ON CONFLICT (jobname)
DO UPDATE SET schedule = EXCLUDED.schedule, command = EXCLUDED.command;

