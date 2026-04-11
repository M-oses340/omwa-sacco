#!/usr/bin/env bash
# =============================================================================
# Omwa Sacco — full deploy via Supabase CLI v2.x
# Usage (from omwa_sacco/ directory): ./scripts/deploy.sh
#
# Prerequisites:
#   supabase login
#   supabase link --project-ref <your-project-ref>
# =============================================================================

set -euo pipefail

# ── Load supabase/.env.local if present ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../supabase/.env.local"

if [ -f "$ENV_FILE" ]; then
  echo "→ Loading supabase/.env.local"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# ── Validate required vars ────────────────────────────────────────────────────
: "${SUPABASE_PROJECT_REF:?SUPABASE_PROJECT_REF is required}"
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${CRON_SECRET:?CRON_SECRET is required}"

SUPABASE_DIR="$SCRIPT_DIR/../supabase"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Omwa Sacco — Supabase Deploy       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Push database migrations ───────────────────────────────────────────────
echo "▶ [1/4] Pushing database migrations..."
supabase db push --linked --workdir "$SUPABASE_DIR/.." --yes
echo "  ✓ Migrations applied"

# ── 2. Write app settings into app_config table ───────────────────────────────
echo ""
echo "▶ [2/4] Writing app config (supabase_url + cron_secret)..."
supabase db query --linked \
  "INSERT INTO public.app_config (key, value)
   VALUES ('supabase_url', '${SUPABASE_URL}'), ('cron_secret', '${CRON_SECRET}')
   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;"
echo "  ✓ app_config updated"

# ── 3. Set edge function secrets ──────────────────────────────────────────────
echo ""
echo "▶ [3/4] Setting edge function secrets..."
supabase secrets set \
  --project-ref "$SUPABASE_PROJECT_REF" \
  CRON_SECRET="$CRON_SECRET"
echo "  ✓ CRON_SECRET set"

# ── 4. Deploy edge functions ──────────────────────────────────────────────────
echo ""
echo "▶ [4/4] Deploying edge functions..."
for fn in "$SUPABASE_DIR"/functions/*/; do
  name=$(basename "$fn")
  [ "$name" = "_shared" ] && continue
  echo "  → $name"
  supabase functions deploy "$name" \
    --project-ref "$SUPABASE_PROJECT_REF" \
    --no-verify-jwt \
    --workdir "$SUPABASE_DIR/.."
done
echo "  ✓ All functions deployed"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Deploy complete ✓                  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Verify cron jobs:"
echo "  supabase db query --linked \"SELECT jobname, schedule, active FROM cron.job WHERE jobname LIKE 'ratiba%';\""
echo ""
echo "Trigger a manual test run:"
echo "  supabase functions invoke ratiba --project-ref $SUPABASE_PROJECT_REF --body '{\"action\":\"run\"}' --header 'x-cron-secret: $CRON_SECRET'"
