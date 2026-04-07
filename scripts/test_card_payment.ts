// Test IntaSend card payment directly via API
// Run from omwa_sacco dir:
// supabase functions invoke fosa --body '{"action":"deposit_card","amount":100}' --no-verify-jwt

// Or run this script directly if you have the keys:
// INTASEND_SECRET_KEY=xxx INTASEND_PUBLISHABLE_KEY=xxx deno run --allow-net --allow-env scripts/test_card_payment.ts

const IS_SECRET = Deno.env.get('INTASEND_SECRET_KEY') || ''
const IS_PUBLIC = Deno.env.get('INTASEND_PUBLISHABLE_KEY') || ''
const IB = 'https://sandbox.intasend.com/api/v1'

if (!IS_SECRET || !IS_PUBLIC) {
  console.error('Missing keys. Run: supabase functions invoke fosa --body \'{"action":"test_card"}\' instead')
  Deno.exit(1)
}

const ref = `TEST-${Date.now()}`

console.log('1. Creating checkout...')
const checkoutRes = await fetch(`${IB}/checkout/`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Authorization': `Token ${IS_SECRET}` },
  body: JSON.stringify({
    public_key: IS_PUBLIC,
    amount: 100,
    currency: 'KES',
    email: 'test@example.com',
    first_name: 'Test',
    last_name: 'User',
    phone_number: '254700000000',
    api_ref: ref,
    redirect_url: 'https://intasend.com/success',
  })
})

const checkout = await checkoutRes.json()
console.log('Checkout:', JSON.stringify(checkout, null, 2))
if (!checkoutRes.ok) Deno.exit(1)

const checkoutId = checkout.id
console.log(`\nCheckout ID: ${checkoutId}`)
console.log(`Checkout URL: ${checkout.url}`)

// Check status after a moment
console.log('\n2. Checking status...')
const statusRes = await fetch(`${IB}/checkout/${checkoutId}/`, {
  headers: { 'Authorization': `Token ${IS_SECRET}` }
})
console.log('Status:', JSON.stringify(await statusRes.json(), null, 2))
