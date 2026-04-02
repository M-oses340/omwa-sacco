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

    const { amount } = await req.json()
    if (!amount || amount < 10) return json({ error: 'Minimum deposit is KES 10' }, 400)

    const { data: member } = await supabase
      .from('members')
      .select('id, full_name, email, phone_number, status')
      .eq('user_id', user.id)
      .single()

    if (!member) return json({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return json({ error: 'Member account is not active' }, 403)

    const { data: fosa } = await supabase
      .from('fosa_accounts')
      .select('id, balance')
      .eq('member_id', member.id)
      .single()

    if (!fosa) return json({ error: 'FOSA account not found' }, 404)

    const reference = `DEP-${Date.now()}`

    const { data: tx } = await supabase
      .from('transactions')
      .insert({
        member_id: member.id,
        account_type: 'fosa',
        transaction_type: 'deposit',
        amount,
        balance_before: fosa.balance,
        reference,
        description: 'FOSA deposit via M-Pesa/Card',
        status: 'pending',
      })
      .select('id')
      .single()

    if (!tx) return json({ error: 'Failed to create transaction' }, 500)

    const nameParts = (member.full_name as string ?? '').split(' ')

    const checkoutRes = await fetch(`${INTASEND_BASE}/checkout/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${INTASEND_SECRET}`,
      },
      body: JSON.stringify({
        public_key: INTASEND_PUB,
        amount,
        currency: 'KES',
        api_ref: reference,
        email: member.email ?? '',
        first_name: nameParts[0] ?? '',
        last_name: nameParts.slice(1).join(' ') ?? '',
        phone_number: member.phone_number ?? '',
        redirect_url: 'https://omwasacco.app/payment/callback',
      }),
    })

    const data = await checkoutRes.json()
    console.log('[CHECKOUT] IntaSend:', checkoutRes.status, JSON.stringify(data))

    if (!checkoutRes.ok || !data.url) {
      await supabase.from('transactions').update({ status: 'failed' }).eq('id', tx.id)
      const errMsg = data?.errors?.[0]?.detail ?? data?.detail ?? data?.message ?? 'Payment initiation failed'
      return json({ error: errMsg }, 500)
    }

    return json({ success: true, checkout_url: data.url, transaction_id: tx.id })
  } catch (e) {
    console.error('[CHECKOUT] Exception:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
