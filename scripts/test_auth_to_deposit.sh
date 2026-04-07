#!/bin/bash
# End-to-end test: Auth → Card Deposit → Webhook → Balance Check
# Usage: bash scripts/test_auth_to_deposit.sh

SUPABASE_URL="https://ttjsokjjkdzfukfbusgw.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR0anNva2pqa2R6ZnVrZmJ1c2d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyODkyMTgsImV4cCI6MjA5MDg2NTIxOH0.FjbwkcNTaXu3gp3-FQQNFNglk8Nl37uf2HXRNSbY9IY"
SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
EMAIL="${1:-mosesomwa7@gmail.com}"
AMOUNT="${2:-100}"

if [ -z "$SERVICE_KEY" ]; then
  echo "ERROR: Set SUPABASE_SERVICE_ROLE_KEY env var"
  echo "Usage: SUPABASE_SERVICE_ROLE_KEY=xxx bash scripts/test_auth_to_deposit.sh"
  exit 1
fi

echo "=== STEP 1: Generate magic link token for $EMAIL ==="
LINK_RESP=$(curl -s -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"email_confirm\":true}")

# Get user ID
USER_ID=$(echo $LINK_RESP | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "User ID: $USER_ID"

echo ""
echo "=== STEP 2: Create a session token ==="
TOKEN_RESP=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"test-password-not-used\"}" 2>/dev/null)

# Try admin token generation instead
TOKEN_RESP=$(curl -s -X POST "$SUPABASE_URL/auth/v1/admin/generate_link" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"magiclink\",\"email\":\"$EMAIL\"}")

echo "Token response: $TOKEN_RESP"
ACCESS_TOKEN=$(echo $TOKEN_RESP | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo ""
  echo "Could not auto-generate token. Using ping to test with existing session..."
  echo "Please provide your JWT from the app logs as argument 3:"
  echo "  bash scripts/test_auth_to_deposit.sh email amount YOUR_JWT"
  ACCESS_TOKEN="${3}"
fi

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: No access token available"
  exit 1
fi

echo "JWT: ${ACCESS_TOKEN:0:30}..."

echo ""
echo "=== STEP 3: Ping fosa function (auth check) ==="
PING=$(curl -s -X POST "$SUPABASE_URL/functions/v1/fosa" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -d "{\"action\":\"ping\",\"jwt\":\"$ACCESS_TOKEN\"}")
echo "Ping: $PING"

echo ""
echo "=== STEP 4: Initiate card deposit of KES $AMOUNT ==="
DEPOSIT=$(curl -s -X POST "$SUPABASE_URL/functions/v1/fosa" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -d "{\"action\":\"deposit_card\",\"amount\":$AMOUNT,\"jwt\":\"$ACCESS_TOKEN\"}")
echo "Deposit: $DEPOSIT"

API_REF=$(echo $DEPOSIT | grep -o '"transaction_id":"[^"]*"' | cut -d'"' -f4)
echo "API Ref: $API_REF"

echo ""
echo "=== STEP 5: Simulate webhook (payment complete) ==="
if [ -n "$API_REF" ]; then
  WEBHOOK=$(curl -s -X POST "$SUPABASE_URL/functions/v1/webhook" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ANON_KEY" \
    -d "{\"invoice_id\":\"TEST-$(date +%s)\",\"state\":\"COMPLETE\",\"api_ref\":\"$API_REF\",\"net_amount\":\"$AMOUNT\",\"value\":\"$AMOUNT\"}")
  echo "Webhook: $WEBHOOK"
else
  echo "SKIP: No api_ref from deposit step"
fi

echo ""
echo "=== STEP 6: Check FOSA balance ==="
BALANCE=$(curl -s "$SUPABASE_URL/rest/v1/fosa_accounts?select=balance,account_number&limit=1" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY")
echo "Balance: $BALANCE"

echo ""
echo "=== TEST COMPLETE ==="
