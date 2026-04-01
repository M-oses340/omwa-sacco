// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY') ?? ''
  const INTASEND_PUB = Deno.env.get('INTASEND_PUBLISHABLE_KEY') ?? ''
  const INTASEND_SANDBOX = Deno.env.get('INTASEND_SANDBOX') === 'true'
  const INTASEND_BASE = INTASEND_SANDBOX
    ? 'https://sandbox.intasend.com/api/v1'
    : 'https://payment.intasend.com/api/v1'

  console.log('[CHECKOUT] secret prefix:', INTASEND_SECRET.substring(0, 15))
  console.log('[CHECKOUT] sandbox:', INTASEND_SANDBOX)

  try {
    // Create a user-scoped client using the request's Authorization header
    const authHeader = req.headers.get('Authorization')
    console.log('[CHECKOUT] auth header present:', !!authHeader)

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Service client for DB operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // User client to verify the JWT
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader ?? '' } },
    })

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser()
    console.log('[CHECKOUT] user:', user?.id ?? 'null', 'error:', authError?.message ?? 'none')

    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const { amount } = await req.json()
    if (!amount || amount < 10) {
      return json({ error: 'Minimum deposit is KES 10' }, 400)
    }

    const { data: member } = await supabaseAdmin
      .from('members')
      .select('id, full_name, email')
      .eq('user_id', user.id)
      .single()

    if (!member) return json({ error: 'Member not found' }, 404)

    const { data: fosa } = await supabaseAdmin
      .from('fosa_accounts')
      .select('id')
      .eq('member_id', member.id)
      .single()

    if (!fosa) return json({ error: 'FOSA account not found' }, 404)

    const reference = `DEP-${Date.now()}`

    const { data: tx } = await supabaseAdmin
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

    const body = JSON.stringify({
      public_key: INTASEND_PUB,
      amount,
      currency: 'KES',
      api_ref: reference,
      email: member.email ?? '',
      first_name: firstName,
      last_name: lastName,
      redirect_url: 'https://omwasacco.app/payment/callback',
    })

    console.log('[CHECKOUT] calling IntaSend:', INTASEND_BASE)

    const res = await fetch(`${INTASEND_BASE}/checkout/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${INTASEND_SECRET}`,
      },
      body,
    })

    const data = await res.json()
    console.log('[CHECKOUT] IntaSend status:', res.status)
    console.log('[CHECKOUT] IntaSend response:', JSON.stringify(data))

    if (!res.ok) {
      const errMsg = (data as any)?.errors?.[0]?.detail
        ?? (data as any)?.error
        ?? (data as any)?.detail
        ?? 'Failed to initiate payment'
      return json({ error: errMsg }, 500)
    }

    return json({
      success: true,
      checkout_url: (data as any).url,
      transaction_id: tx!.id,
    })
  } catch (e) {
    console.error('[CHECKOUT] Exception:', (e as Error).message, (e as Error).stack)
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
