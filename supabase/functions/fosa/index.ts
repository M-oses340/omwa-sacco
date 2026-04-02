// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { jwtUserId, jsonResponse as json } from '../_shared/auth.ts'

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
  const userId = jwtUserId(req.headers.get('Authorization'))
  if (!userId) return json({ error: 'Unauthorized' }, 401)

  try {
    const body = await req.json()
    switch (body.action) {
      case 'deposit_mpesa':   return await depositMpesa(userId, body)
      case 'deposit_card':    return await depositCard(userId, body)
      case 'withdraw':        return await withdraw(userId, body)
      default:                return json({ error: 'Invalid action' }, 400)
    }
  } catch (e) {
    console.error('[FOSA]', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

async function getMemberAndFosa(userId: string) {
  const { data: member } = await supabase
    .from('members').select('id, full_name, email, phone_number, status')
    .eq('user_id', userId).single()
  if (!member) return { error: 'Member not found', status: 404 }
  if (member.status !== 'active') return { error: 'Account not active', status: 403 }

  const { data: fosa } = await supabase
    .from('fosa_accounts').select('id, account_number, balance')
    .eq('member_id', member.id).single()
  if (!fosa) return { error: 'FOSA account not found', status: 404 }

  return { member, fosa }
}

// ── M-Pesa STK Push deposit ───────────────────────────────────────────────────
async function depositMpesa(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 10) return json({ error: 'Minimum deposit is KES 10' }, 400)

  const result = await getMemberAndFosa(userId)
  if ('error' in result) return json({ error: result.error }, result.status)
  const { member, fosa } = result

  const { data: tx } = await supabase.from('transactions').insert({
    member_id: member.id, account_type: 'fosa', transaction_type: 'deposit',
    amount, balance_before: fosa.balance,
    description: 'FOSA deposit via M-Pesa STK Push', status: 'pending',
  }).select('id').single()

  if (!tx) return json({ error: 'Failed to create transaction' }, 500)

  const phone = member.phone_number.startsWith('+')
    ? member.phone_number.slice(1)
    : member.phone_number.startsWith('0')
    ? `254${member.phone_number.slice(1)}`
    : member.phone_number

  const res = await fetch(`${INTASEND_BASE}/payment/mpesa-stk-push/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${INTASEND_SECRET}` },
    body: JSON.stringify({
      amount, phone_number: phone,
      api_ref: `${member.id}:fosa:${tx.id}`,
      narrative: `Omwa Sacco FOSA Deposit - ${fosa.account_number}`,
    }),
  })

  const data = await res.json()
  console.log('[FOSA] STK push:', res.status, JSON.stringify(data))

  if (!res.ok) {
    await supabase.from('transactions').update({ status: 'failed' }).eq('id', tx.id)
    return json({ error: data?.detail ?? data?.message ?? 'STK push failed' }, 400)
  }

  await supabase.from('transactions').update({ intasend_ref: data?.invoice?.invoice_id }).eq('id', tx.id)
  return json({ success: true, message: 'M-Pesa prompt sent. Enter your PIN to complete.', transaction_id: tx.id })
}

// ── Card / Bank checkout deposit ──────────────────────────────────────────────
async function depositCard(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 10) return json({ error: 'Minimum deposit is KES 10' }, 400)

  const result = await getMemberAndFosa(userId)
  if ('error' in result) return json({ error: result.error }, result.status)
  const { member, fosa } = result

  const reference = `DEP-${Date.now()}`
  const { data: tx } = await supabase.from('transactions').insert({
    member_id: member.id, account_type: 'fosa', transaction_type: 'deposit',
    amount, balance_before: fosa.balance, reference,
    description: 'FOSA deposit via Card/Bank', status: 'pending',
  }).select('id').single()

  if (!tx) return json({ error: 'Failed to create transaction' }, 500)

  const nameParts = (member.full_name ?? '').split(' ')
  const res = await fetch(`${INTASEND_BASE}/checkout/`, {
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

  const data = await res.json()
  console.log('[FOSA] Checkout:', res.status, JSON.stringify(data))

  if (!res.ok || !data.url) {
    await supabase.from('transactions').update({ status: 'failed' }).eq('id', tx.id)
    return json({ error: data?.errors?.[0]?.detail ?? data?.detail ?? data?.message ?? 'Checkout failed' }, 500)
  }

  return json({ success: true, checkout_url: data.url, transaction_id: tx.id })
}

// ── M-Pesa B2C withdrawal ─────────────────────────────────────────────────────
async function withdraw(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 100) return json({ error: 'Minimum withdrawal is KES 100' }, 400)

  const result = await getMemberAndFosa(userId)
  if ('error' in result) return json({ error: result.error }, result.status)
  const { member, fosa } = result

  const balance = parseFloat(fosa.balance)
  if (amount > balance) return json({ error: `Insufficient balance. Available: KES ${balance.toFixed(2)}` }, 400)

  const phone = member.phone_number
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
  if (!res.ok) return json({ error: data?.errors?.[0]?.detail ?? 'Withdrawal failed' }, 400)

  const reference = `WDR-${Date.now()}`
  const newBalance = balance - amount
  await supabase.from('fosa_accounts').update({ balance: newBalance, updated_at: new Date().toISOString() }).eq('id', fosa.id)
  await supabase.from('transactions').insert({
    member_id: member.id, account_type: 'fosa', transaction_type: 'withdrawal',
    amount, balance_before: balance, balance_after: newBalance,
    reference, description: `M-Pesa withdrawal to ${phone}`, status: 'pending',
  })

  return json({ success: true })
}
