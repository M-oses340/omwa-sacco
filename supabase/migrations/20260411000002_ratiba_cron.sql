-- ============================================================
-- Ratiba Cron Jobs — pg_cron + pg_net
-- Schedule 1: 06:00 EAT (03:00 UTC) — main daily run
-- Schedule 2: 12:00 EAT (09:00 UTC) — midday retry (low-balance members)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── App config table (no superuser needed) ────────────────────────────────────
-- Stores non-auth config like the cron secret.
-- Populated by the deploy script via: supabase db query --linked
CREATE TABLE IF NOT EXISTS public.app_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Only service role can read/write
REVOKE ALL ON public.app_config FROM anon, authenticated;

-- ── Helper function ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_ratiba_run()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url    TEXT;
  v_secret TEXT;
BEGIN
  SELECT value INTO v_url    FROM public.app_config WHERE key = 'supabase_url';
  SELECT value INTO v_secret FROM public.app_config WHERE key = 'cron_secret';

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/ratiba',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'x-cron-secret', v_secret
    ),
    body    := '{"action":"run"}'::jsonb
  );
END;
$$;

-- ── Cron schedules ────────────────────────────────────────────────────────────
SELECT cron.schedule(
  'ratiba-morning-run',
  '0 3 * * *',
  $$ SELECT public.trigger_ratiba_run(); $$
);

SELECT cron.schedule(
  'ratiba-midday-retry',
  '0 9 * * *',
  $$ SELECT public.trigger_ratiba_run(); $$
);

-- ── Monitoring view ───────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.ratiba_cron_log AS
SELECT
  jrd.runid,
  j.jobname,
  jrd.start_time,
  jrd.end_time,
  EXTRACT(EPOCH FROM (jrd.end_time - jrd.start_time))::int AS duration_seconds,
  jrd.status,
  jrd.return_message
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE j.jobname LIKE 'ratiba%'
ORDER BY jrd.start_time DESC;

GRANT SELECT ON public.ratiba_cron_log TO authenticated;
