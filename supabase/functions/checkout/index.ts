// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Decode JWT payload — gateway already verified the signature
function decodeJwt(token: string): any {
  try {
    const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(atob(payload + '='.repeat((4 - payload.length % 4) % 4)))
  } catch { return null }
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } }
)

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) return json({ error: 'Unauthorized' }, 401)

    const token = authHeader.replace('Bearer ', '')
    const payload = decodeJwt(token)
    console.log('[CHECKOUT] sub:', payload?.sub, 'role:', payload?.role)

    if (!payload?.sub || payload.role !== 'authenticated') return json({ error: 'Unauthorized' }, 401)
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return json({ error: 'Token expired' }, 401)

    const userId = payload.sub as string

    // Validate token via supabase auth (same pattern as process-loan which works)
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    console.log('[CHECKOUT] auth user:', user?.id ?? 'null', authError?.message ?? '')
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const body = await req.json().catch(() => ({}))
    const { amount } = body
    if (!amount || amount < 10) return json({ error: 'Minimum deposit is KES 10' }, 400)

    const intasendSecret = Deno.env.get('INTASEND_SECRET_KEY')!
    const intasendPub = Deno.env.get('INTASEND_PUBLISHABLE_KEY') ?? Deno.env.get('INTASEND_PUBLIC_KEY') ?? ''
    const isSandbox = Deno.env.get('INTASEND_SANDBOX') === 'true'
    const intasendBase = isSandbox ? 'https://sandbox.intasend.com/api/v1' : 'https://payment.intasend.com/api/v1'
    console.log('[CHECKOUT] amount:', amount, 'sandbox:', isSandbox)

    const { data: member, error: memberErr } = await supabase
      .from('members')
      .select('id, full_name, email, phone_number, status')
      .eq('user_id', userId)
      .single()

    console.log('[CHECKOUT] member:', member?.id ?? 'null', memberErr?.message ?? '')
    if (!member) return json({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return json({ error: 'Member account is not active' }, 403)

    const { data: fosa } = await supabase
      .from('fosa_accounts')
      .select('id, balance')
      .eq('member_id', member.id)
      .single()

    console.log('[CHECKOUT] fosa:', fosa?.id ?? 'null')
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

    console.log('[CHECKOUT] tx:', tx?.id ?? 'null')
    if (!tx) return json({ error: 'Failed to create transaction' }, 500)

    const nameParts = (member.full_name ?? '').split(' ')
    const checkoutRes = await fetch(`${intasendBase}/checkout/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${intasendSecret}` },
      body: JSON.stringify({
        public_key: intasendPub,
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

    const checkoutData = await checkoutRes.json()
    console.log('[CHECKOUT] IntaSend:', checkoutRes.status, JSON.stringify(checkoutData))

    if (!checkoutRes.ok || !checkoutData.url) {
      await supabase.from('transactions').update({ status: 'failed' }).eq('id', tx.id)
      const errMsg = checkoutData?.errors?.[0]?.detail ?? checkoutData?.detail ?? checkoutData?.message ?? 'Payment initiation failed'
      return json({ error: errMsg }, 500)
    }

    return json({ success: true, checkout_url: checkoutData.url, transaction_id: tx.id })
  } catch (e) {
    console.error('[CHECKOUT] Exception:', (e as Error).message, (e as Error).stack)
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } })
}
