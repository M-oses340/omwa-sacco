import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY')!
const INTASEND_BASE = Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'

Deno.serve(async (req) => {
  try {
    // Verify auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const { amount } = await req.json()
    if (!amount || amount < 10) {
      return json({ error: 'Minimum deposit is KES 10' }, 400)
    }

    // Get member + FOSA account
    const { data: member } = await supabase
      .from('members')
      .select('id, full_name, email, phone_number')
      .eq('user_id', user.id)
      .single()

    if (!member) return json({ error: 'Member not found' }, 404)

    const { data: fosa } = await supabase
      .from('fosa_accounts')
      .select('id, account_number')
      .eq('member_id', member.id)
      .single()

    if (!fosa) return json({ error: 'FOSA account not found' }, 404)

    // Create pending transaction
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

    // Initiate IntaSend checkout
    const checkoutRes = await fetch(`${INTASEND_BASE}/checkout/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${INTASEND_SECRET}`,
      },
      body: JSON.stringify({
        public_key: Deno.env.get('INTASEND_PUBLISHABLE_KEY'),
        amount,
        currency: 'KES',
        api_ref: reference,
        email: member.email ?? '',
        first_name: member.full_name.split(' ')[0],
        last_name: member.full_name.split(' ').slice(1).join(' ') || '',
        redirect_url: 'https://omwasacco.app/payment/callback',
      }),
    })

    const checkoutData = await checkoutRes.json()

    if (!checkoutRes.ok) {
      console.error('[CHECKOUT] IntaSend error:', checkoutData)
      return json({ error: 'Failed to initiate payment' }, 500)
    }

    return json({
      success: true,
      checkout_url: checkoutData.url,
      transaction_id: tx!.id,
    })
  } catch (e) {
    console.error('[CHECKOUT] Error:', e.message)
    return json({ error: e.message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
