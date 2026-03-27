import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const INTASEND_API_URL = 'https://sandbox.intasend.com/api/v1'
const INTASEND_SECRET_KEY = Deno.env.get('INTASEND_SECRET_KEY')!

Deno.serve(async (req) => {
  try {
    // Get authenticated user
    const authHeader = req.headers.get('Authorization')!
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const { amount } = await req.json()

    if (!amount || amount < 1) {
      return new Response(JSON.stringify({ error: 'Invalid amount' }), { status: 400 })
    }

    // Fetch member record — phone number comes from DB, never from client
    const { data: member, error: memberError } = await supabase
      .from('members')
      .select('id, phone_number, status')
      .eq('user_id', user.id)
      .single()

    if (memberError || !member) {
      return new Response(JSON.stringify({ error: 'Member not found' }), { status: 404 })
    }

    if (member.status !== 'active') {
      return new Response(JSON.stringify({ error: 'Member account is not active' }), { status: 403 })
    }

    // Fetch FOSA account
    const { data: fosa, error: fosaError } = await supabase
      .from('fosa_accounts')
      .select('id, account_number, balance')
      .eq('member_id', member.id)
      .single()

    if (fosaError || !fosa) {
      return new Response(JSON.stringify({ error: 'FOSA account not found' }), { status: 404 })
    }

    // Create pending transaction
    const { data: transaction, error: txError } = await supabase
      .from('transactions')
      .insert({
        member_id: member.id,
        account_type: 'fosa',
        transaction_type: 'deposit',
        amount: amount,
        balance_before: fosa.balance,
        description: 'FOSA deposit via M-Pesa',
        status: 'pending',
      })
      .select('id')
      .single()

    if (txError || !transaction) {
      return new Response(JSON.stringify({ error: 'Failed to create transaction' }), { status: 500 })
    }

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

    if (!stkResponse.ok) {
      // Mark transaction as failed
      await supabase.from('transactions').update({ status: 'failed' }).eq('id', transaction.id)
      return new Response(JSON.stringify({ error: stkData.detail || 'STK push failed' }), { status: 400 })
    }

    // Update transaction with IntaSend reference
    await supabase.from('transactions')
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
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
