// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY')!
const INTASEND_PUB = Deno.env.get('INTASEND_PUBLISHABLE_KEY') ?? Deno.env.get('INTASEND_PUBLIC_KEY') ?? ''
const INTASEND_BASE = Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Unauthorized' }, 401)

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const body = await req.json()

    // Route: action=checkout → card/bank deposit; default → M-Pesa withdrawal
    if (body.action === 'checkout') return await handleCheckout(user.id, body)
    return await handleWithdrawal(user.id, body)
  } catch (e) {
    console.error('[FOSA] Error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

// ── Card/Bank deposit via IntaSend checkout URL ───────────────────────────────
async function handleCheckout(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 10) return json({ error: 'Minimum deposit is KES 10' }, 400)

  const { data: member } = await supabase
    .from('members')
    .select('id, full_name, email, phone_number, status')
    .eq('user_id', userId)
    .single()

  if (!member) return json({ error: 'Member not found' }, 404)
  if (member.status !== 'active') return json({ error: 'Member account is not active' }, 403)

  const { data: fosa } = await supabase
    .from('fosa_accounts').select('id, balance').eq('member_id', member.id).single()
  if (!fosa) return json({ error: 'FOSA account not found' }, 404)

  const reference = `DEP-${Date.now()}`
  const { data: tx } = await supabase.from('transactions').insert({
    member_id: member.id, account_type: 'fosa', transaction_type: 'deposit',
    amount, balance_before: fosa.balance, reference,
    description: 'FOSA deposit via Card/Bank', status: 'pending',
  }).select('id').single()

  if (!tx) return json({ error: 'Failed to create transaction' }, 500)

  const nameParts = (member.full_name ?? '').split(' ')
  const checkoutRes = await fetch(`${INTASEND_BASE}/checkout/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${INTASEND_SECRET}` },
    body: JSON.stringify({
      public_key: INTASEND_PUB, amount, currency: 'KES', api_ref: reference,
      email: member.email ?? '', first_name: nameParts[0] ?? '',
      last_name: nameParts.slice(1).join(' ') ?? '',
      phone_number: member.phone_number ?? '',
      redirect_url: 'https://omwasacco.app/payment/callback',
    }),
  })

  const checkoutData = await checkoutRes.json()
  console.log('[CHECKOUT] IntaSend:', checkoutRes.status, JSON.stringify(checkoutData))

  if (!checkoutRes.ok || !checkoutData.url) {
    await supabase.from('transactions').update({ status: 'failed' }).eq('id', tx.id)
    const errMsg = checkoutData?.errors?.[0]?.detail ?? checkoutData?.detail ?? checkoutData?.message ?? 'Payment initiation failed'
    return json({ error: errMsg }, 500)
  }

  return json({ success: true, checkout_url: checkoutData.url, transaction_id: tx.id })
}

// ── M-Pesa B2C withdrawal ─────────────────────────────────────────────────────
async function handleWithdrawal(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 100) return json({ error: 'Minimum withdrawal is KES 100' }, 400)

  const { data: member } = await supabase
    .from('members').select('id, full_name, phone_number').eq('user_id', userId).single()
  if (!member) return json({ error: 'Member not found' }, 404)

  const phone = member.phone_number
  const { data: fosa } = await supabase
    .from('fosa_accounts').select('id, balance').eq('member_id', member.id).single()
  if (!fosa) return json({ error: 'FOSA account not found' }, 404)

  const balance = parseFloat(fosa.balance)
  if (amount > balance) {
    return json({ error: `Insufficient balance. Available: KES ${balance.toFixed(2)}` }, 400)
  }

  const normalised = phone.startsWith('+') ? phone.slice(1)
    : phone.startsWith('0') ? `254${phone.slice(1)}` : phone

  const res = await fetch(`${INTASEND_BASE}/send-money/initiate/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${INTASEND_SECRET}` },
    body: JSON.stringify({
      currency: 'KES', provider: 'MPESA-B2C', requires_approval: 'NO',
      transactions: [{ name: member.full_name, account: normalised, amount: amount.toString(), narrative: 'FOSA withdrawal - Omwa Sacco' }],
    }),
  })

  const data = await res.json()
  console.log('[WITHDRAWAL] IntaSend:', JSON.stringify(data))

  if (!res.ok) {
    return json({ error: data?.errors?.[0]?.detail ?? 'M-Pesa withdrawal failed' }, 400)
  }

  const reference = `WDR-${Date.now()}`
  const newBalance = balance - amount

  await supabase.from('fosa_accounts')
    .update({ balance: newBalance, updated_at: new Date().toISOString() }).eq('id', fosa.id)

  await supabase.from('transactions').insert({
    member_id: member.id, account_type: 'fosa', transaction_type: 'withdrawal',
    amount, balance_before: balance, balance_after: newBalance,
    reference, description: `M-Pesa withdrawal to ${phone}`, status: 'pending',
  })

  return json({ success: true })
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
