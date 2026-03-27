import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    const { invoice_id, state, net_amount, api_ref, mpesa_code } = payload

    // api_ref format: "memberId:accountType:transactionId"
    const parts = (api_ref ?? '').split(':')
    if (parts.length !== 3) {
      return new Response(JSON.stringify({ error: 'Invalid api_ref' }), { status: 400 })
    }

    const [memberId, accountType, transactionId] = parts
    const amount = parseFloat(net_amount)

    if (state === 'COMPLETE') {
      // Fetch current balance
      const { data: fosa } = await supabase
        .from('fosa_accounts')
        .select('balance')
        .eq('member_id', memberId)
        .single()

      if (!fosa) {
        return new Response(JSON.stringify({ error: 'Account not found' }), { status: 404 })
      }

      const newBalance = (fosa.balance ?? 0) + amount

      // Credit FOSA account
      await supabase
        .from('fosa_accounts')
        .update({ balance: newBalance })
        .eq('member_id', memberId)

      // Update transaction to completed
      await supabase
        .from('transactions')
        .update({
          status: 'completed',
          balance_after: newBalance,
          intasend_ref: invoice_id,
          mpesa_ref: mpesa_code,
        })
        .eq('id', transactionId)

    } else if (state === 'FAILED') {
      await supabase
        .from('transactions')
        .update({ status: 'failed', intasend_ref: invoice_id })
        .eq('id', transactionId)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
