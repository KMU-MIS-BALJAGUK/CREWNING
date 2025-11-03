select
  cron.schedule(
    'weekly-reset',         -- 작업 이름
    '0 15 * * 0',           -- 매주 월요일 00:00 (KST) -> 일요일 15:00 (UTC)
    $$
    select
      net.http_post(
        url     := 'https://uzteyczbmedsjqgrgega.supabase.co/functions/v1/reset-weekly',
        headers := '{
          "Content-Type": "application/json",
          "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV6dGV5Y3pibWVkc2pxZ3JnZWdhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTczMDI0NSwiZXhwIjoyMDc3MzA2MjQ1fQ.ucpJoA3VOkmQf-NEYN9aGASyDu1611Gj_olZRoa8FA8"
        }'::jsonb,
        body := jsonb_build_object('invoked_at', now())
      ) as request_id;
    $$::text
  );