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
    const [memberId, accountType, transactionId] = (api_ref ?? '').split(':')

    if (state === 'COMPLETE') {
      // Update transaction status
      await supabase
        .from('transactions')
        .update({
          status: 'completed',
          intasend_ref: invoice_id,
          mpesa_ref: mpesa_code,
          updated_at: new Date().toISOString(),
        })
        .eq('id', transactionId)

      // Credit the account
      const table = accountType === 'fosa' ? 'fosa_accounts' : 'bosa_accounts'
      const balanceField = accountType === 'fosa' ? 'balance' : 'savings_balance'

      const { data: account } = await supabase
        .from(table)
        .select(balanceField)
        .eq('member_id', memberId)
        .single()

      if (account) {
        const newBalance = (account[balanceField] ?? 0) + parseFloat(net_amount)
        await supabase
          .from(table)
          .update({ [balanceField]: newBalance })
          .eq('member_id', memberId)
      }
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
