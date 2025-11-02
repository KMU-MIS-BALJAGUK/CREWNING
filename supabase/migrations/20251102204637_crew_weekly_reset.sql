-- Function to zero weekly_score
CREATE OR REPLACE FUNCTION public.reset_weekly_scores()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public."user" SET weekly_score = 0;
$$;

-- Upsert cron job (run Sunday 15:00 UTC == Monday 00:00 KST)
SELECT cron.unschedule('reset_weekly_user_scores');
SELECT cron.schedule(
  'reset_weekly_user_scores',
  '0 15 * * 0',
  $$SELECT public.reset_weekly_scores();$$
);
