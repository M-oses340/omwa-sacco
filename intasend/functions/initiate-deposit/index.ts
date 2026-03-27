import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const INTASEND_API_URL = 'https://sandbox.intasend.com/api/v1'
const INTASEND_SECRET_KEY = Deno.env.get('INTASEND_SECRET_KEY')!

Deno.serve(async (req) => {
  try {
    // Get JWT from Authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const jwt = authHeader.replace('Bearer ', '')

    // Create client with user's JWT to respect RLS
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: `Bearer ${jwt}` } } }
    )

    // Service role client for writes that bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get authenticated user
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser()
    if (authError || !user) {
      console.error('[DEPOSIT] Auth error:', authError?.message)
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    console.log('[DEPOSIT] Authenticated user:', user.id)

    const { amount } = await req.json()

    if (!amount || amount < 1) {
      return new Response(JSON.stringify({ error: 'Invalid amount' }), { status: 400 })
    }

    // Fetch member — phone comes from DB only
    const { data: member, error: memberError } = await supabaseAdmin
      .from('members')
      .select('id, phone_number, status')
      .eq('user_id', user.id)
      .single()

    if (memberError || !member) {
      console.error('[DEPOSIT] Member not found:', memberError?.message)
      return new Response(JSON.stringify({ error: 'Member not found' }), { status: 404 })
    }

    if (member.status !== 'active') {
      return new Response(JSON.stringify({ error: 'Member account is not active' }), { status: 403 })
    }

    // Fetch FOSA account
    const { data: fosa, error: fosaError } = await supabaseAdmin
      .from('fosa_accounts')
      .select('id, account_number, balance')
      .eq('member_id', member.id)
      .single()

    if (fosaError || !fosa) {
      console.error('[DEPOSIT] FOSA not found:', fosaError?.message)
      return new Response(JSON.stringify({ error: 'FOSA account not found' }), { status: 404 })
    }

    // Create pending transaction
    const { data: transaction, error: txError } = await supabaseAdmin
      .from('transactions')
      .insert({
        member_id: member.id,
        account_type: 'fosa',
        transaction_type: 'deposit',
        amount: amount,
        balance_before: fosa.balance,
        description: 'FOSA deposit via M-Pesa STK Push',
        status: 'pending',
      })
      .select('id')
      .single()

    if (txError || !transaction) {
      console.error('[DEPOSIT] Transaction insert error:', txError?.message)
      return new Response(JSON.stringify({ error: 'Failed to create transaction' }), { status: 500 })
    }

    console.log('[DEPOSIT] Transaction created:', transaction.id)

    // Initiate STK Push via IntaSend
    const stkResponse = await fetch(`${INTASEND_API_URL}/payment/mpesa-stk-push/`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${INTASEND_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amount,
        phone_number: member.phone_number,
        api_ref: `${member.id}:fosa:${transaction.id}`,
        narrative: `Omwa Sacco FOSA Deposit - ${fosa.account_number}`,
      }),
    })

    const stkData = await stkResponse.json()
    console.log('[DEPOSIT] IntaSend response:', JSON.stringify(stkData))

    if (!stkResponse.ok) {
      await supabaseAdmin.from('transactions').update({ status: 'failed' }).eq('id', transaction.id)
      return new Response(JSON.stringify({ error: stkData.detail || stkData.message || 'STK push failed' }), { status: 400 })
    }

    // Update transaction with IntaSend reference
    await supabaseAdmin.from('transactions')
      .update({ intasend_ref: stkData.invoice?.invoice_id })
      .eq('id', transaction.id)

    return new Response(JSON.stringify({
      success: true,
      message: 'STK push sent. Enter your M-Pesa PIN to complete.',
      transaction_id: transaction.id,
      invoice_id: stkData.invoice?.invoice_id,
    }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('[DEPOSIT] Unexpected error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
