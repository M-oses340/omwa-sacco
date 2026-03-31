// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY')!
const INTASEND_PUB = Deno.env.get('INTASEND_PUBLISHABLE_KEY')!
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
    if (!amount || amount < 10) {
      return json({ error: 'Minimum deposit is KES 10' }, 400)
    }

    const { data: member } = await supabase
      .from('members')
      .select('id, full_name, email')
      .eq('user_id', user.id)
      .single()

    if (!member) return json({ error: 'Member not found' }, 404)

    const { data: fosa } = await supabase
      .from('fosa_accounts')
      .select('id')
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
        reference,
        description: 'FOSA deposit via M-Pesa/Card',
        status: 'pending',
      })
      .select('id')
      .single()

    const nameParts = (member.full_name as string).split(' ')
    const firstName = nameParts[0]
    const lastName = nameParts.slice(1).join(' ') || ''

    const res = await fetch(`${INTASEND_BASE}/checkout/`, {
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
        first_name: firstName,
        last_name: lastName,
        redirect_url: 'https://omwasacco.app/payment/callback',
      }),
    })

    const data = await res.json()
    console.log('[CHECKOUT] IntaSend response:', JSON.stringify(data))

    if (!res.ok) {
      const errMsg = (data as any)?.errors?.[0]?.detail ?? 'Failed to initiate payment'
      return json({ error: errMsg }, 500)
    }

    return json({
      success: true,
      checkout_url: (data as any).url,
      transaction_id: tx!.id,
    })
  } catch (e) {
    console.error('[CHECKOUT] Error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
