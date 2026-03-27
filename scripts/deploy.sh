#!/bin/bash

# Omwa Sacco - Deployment Script
# Usage: ./scripts/deploy.sh [supabase|intasend|all]

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
      supabase functions deploy "$func_name" --project-ref "$PROJECT_REF"
    fi
  done
  echo "✅ Supabase functions deployed"
}

deploy_intasend_functions() {
  echo "💳 Deploying IntaSend functions..."
  for dir in "$ROOT_DIR/intasend/functions"/*/; do
    func_name=$(basename "$dir")
    if [ -f "$dir/index.ts" ]; then
      echo "  → Copying $func_name to supabase/functions/"
      cp -r "$dir" "$ROOT_DIR/supabase/functions/$func_name"
      echo "  → Deploying $func_name"
      supabase functions deploy "$func_name" --project-ref "$PROJECT_REF" --no-verify-jwt
      echo "  → Cleaning up temp copy"
      rm -rf "$ROOT_DIR/supabase/functions/$func_name"
    fi
  done
  echo "✅ IntaSend functions deployed"
}

deploy_migrations() {
  echo "🗄️  Pushing database migrations..."
  supabase db push --project-ref "$PROJECT_REF"
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
