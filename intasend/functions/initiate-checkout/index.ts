import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const INTASEND_API_URL = 'https://sandbox.intasend.com/api/v1'
const INTASEND_SECRET_KEY = Deno.env.get('INTASEND_SECRET_KEY')!
const INTASEND_PUBLIC_KEY = Deno.env.get('INTASEND_PUBLIC_KEY')!

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const jwt = authHeader.replace('Bearer ', '')
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: `Bearer ${jwt}` } } }
    )
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const { amount } = await req.json()
    if (!amount || amount < 10) {
      return new Response(JSON.stringify({ error: 'Minimum deposit is KES 10' }), { status: 400 })
    }

    const { data: member } = await supabaseAdmin
      .from('members')
      .select('id, full_name, email, phone_number, status')
      .eq('user_id', user.id)
      .single()

    if (!member || member.status !== 'active') {
      return new Response(JSON.stringify({ error: 'Member not found or inactive' }), { status: 404 })
    }

    const { data: fosa } = await supabaseAdmin
      .from('fosa_accounts')
      .select('id, account_number, balance')
      .eq('member_id', member.id)
      .single()

    if (!fosa) {
      return new Response(JSON.stringify({ error: 'FOSA account not found' }), { status: 404 })
    }

    // Create pending transaction
    const { data: transaction } = await supabaseAdmin
      .from('transactions')
      .insert({
        member_id: member.id,
        account_type: 'fosa',
        transaction_type: 'deposit',
        amount: amount,
        balance_before: fosa.balance,
        description: 'FOSA deposit via Bank/Card',
        status: 'pending',
      })
      .select('id')
      .single()

    if (!transaction) {
      return new Response(JSON.stringify({ error: 'Failed to create transaction' }), { status: 500 })
    }

    // Create checkout via IntaSend API (public key only for checkout)
    const nameParts = (member.full_name ?? '').split(' ')
    const checkoutResponse = await fetch(`${INTASEND_API_URL}/checkout/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        public_key: INTASEND_PUBLIC_KEY,
        amount: amount,
        currency: 'KES',
        email: member.email ?? '',
        first_name: nameParts[0] ?? '',
        last_name: nameParts.slice(1).join(' ') ?? '',
        phone_number: member.phone_number ?? '',
        api_ref: `${member.id}:fosa:${transaction.id}`,
        redirect_url: 'https://omwasacco.app/payment/callback',
        comment: `Omwa Sacco FOSA Deposit - ${fosa.account_number}`,
        // No method specified — shows both Card and M-Pesa tabs
      }),
    })

    const checkoutData = await checkoutResponse.json()
    console.log('[BANK-DEPOSIT] Checkout response:', JSON.stringify(checkoutData))

    if (!checkoutResponse.ok || !checkoutData.url) {
      await supabaseAdmin.from('transactions').update({ status: 'failed' }).eq('id', transaction.id)
      const errMsg = checkoutData.detail || checkoutData.message || JSON.stringify(checkoutData)
      console.error('[BANK-DEPOSIT] Checkout failed:', errMsg)
      return new Response(JSON.stringify({ error: errMsg }), { status: 400 })
    }

    return new Response(JSON.stringify({
      success: true,
      checkout_url: checkoutData.url,
      transaction_id: transaction.id,
    }), { headers: { 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('[BANK-DEPOSIT] Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
