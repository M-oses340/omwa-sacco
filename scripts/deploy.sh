#!/bin/bash

# Omwa Sacco - Deployment Script
# Usage: ./scripts/deploy.sh [supabase|intasend|migrations|all]
#
# IMPORTANT: intasend functions are deployed from a temp directory.
# They NEVER overwrite files in supabase/functions/.

PROJECT_REF="rzkudmfuutszspzfhzne"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Omwa Sacco Deploy Script"
echo "Project: $PROJECT_REF"
echo ""

deploy_supabase_functions() {
  echo "📦 Deploying Supabase functions..."
  for dir in "$ROOT_DIR/supabase/functions"/*/; do
    func_name=$(basename "$dir")
    if [ -f "$dir/index.ts" ]; then
      echo "  → Deploying $func_name"
      supabase functions deploy "$func_name" --no-verify-jwt
    fi
  done
  echo "✅ Supabase functions deployed"
}

deploy_intasend_functions() {
  echo "💳 Deploying IntaSend functions..."
  TMPDIR=$(mktemp -d)
  for dir in "$ROOT_DIR/intasend/functions"/*/; do
    func_name=$(basename "$dir")
    if [ -f "$dir/index.ts" ]; then
      # Skip if already managed in supabase/functions/
      if [ -d "$ROOT_DIR/supabase/functions/$func_name" ]; then
        echo "  → Skipping $func_name (managed in supabase/functions/)"
        continue
      fi
      echo "  → Deploying $func_name from intasend/"
      # Copy to temp dir and deploy from there — never touch supabase/functions/
      cp -r "$dir" "$TMPDIR/$func_name"
      supabase functions deploy "$func_name" --no-verify-jwt
    fi
  done
  rm -rf "$TMPDIR"
  echo "✅ IntaSend functions deployed"
}

deploy_migrations() {
  echo "🗄️  Pushing database migrations..."
  supabase db push --linked --yes
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
