#!/bin/bash

# Omwa Sacco - Deployment Script
# Usage: ./scripts/deploy.sh [supabase|intasend|migrations|all]
#
# IMPORTANT: intasend functions are deployed from their source directory.
# They NEVER overwrite files in supabase/functions/.

PROJECT_REF="ttjsokjjkdzfukfbusgw"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Use updated CLI if available, fall back to system CLI
SUPABASE_CLI="${SUPABASE_CLI:-$(which supabase)}"
if [ -f "/tmp/supabase" ]; then
  SUPABASE_CLI="/tmp/supabase"
fi

echo "🚀 Omwa Sacco Deploy Script"
echo "Project: $PROJECT_REF"
echo "CLI: $($SUPABASE_CLI --version 2>&1 | head -1)"
echo ""

deploy_supabase_functions() {
  echo "📦 Deploying Supabase functions..."
  for dir in "$ROOT_DIR/supabase/functions"/*/; do
    func_name=$(basename "$dir")
    if [ -f "$dir/index.ts" ]; then
      echo "  → Deploying $func_name"
      $SUPABASE_CLI functions deploy "$func_name" --no-verify-jwt
    fi
  done
  echo "✅ Supabase functions deployed"
}

deploy_intasend_functions() {
  echo "💳 Deploying IntaSend functions..."
  for dir in "$ROOT_DIR/intasend/functions"/*/; do
    func_name=$(basename "$dir")
    if [ -f "$dir/index.ts" ]; then
      if [ -d "$ROOT_DIR/supabase/functions/$func_name" ]; then
        echo "  → Skipping $func_name (managed in supabase/functions/)"
        continue
      fi
      echo "  → Deploying $func_name from intasend/"
      $SUPABASE_CLI functions deploy "$func_name" --no-verify-jwt
    fi
  done
  echo "✅ IntaSend functions deployed"
}

deploy_migrations() {
  echo "🗄️  Pushing database migrations..."
  $SUPABASE_CLI db push --linked --yes
  echo "✅ Migrations pushed"
}

case "${1:-all}" in
  supabase)
    deploy_supabase_functions
    ;;
  intasend)
    deploy_intasend_functions
    ;;
  migrations)
    deploy_migrations
    ;;
  all)
    deploy_migrations
    deploy_supabase_functions
    deploy_intasend_functions
    ;;
  *)
    echo "Usage: $0 [supabase|intasend|migrations|all]"
    exit 1
    ;;
esac

echo ""
echo "🎉 Done!"
