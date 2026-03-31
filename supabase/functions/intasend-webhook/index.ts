import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    console.log('[WEBHOOK] IntaSend payload:', JSON.stringify(payload))

    // Verify challenge secret
    const challenge = Deno.env.get('INTASEND_CHALLENGE')
    if (challenge && payload.challenge !== challenge) {
      console.error('[WEBHOOK] Invalid challenge')
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // IntaSend webhook payload fields
    const {
      invoice_id,
      state,
      net_amount,
      api_ref,
      mpesa_code,
    } = payload

    if (!api_ref) {
      return new Response(JSON.stringify({ error: 'Missing api_ref' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Look up the transaction by our reference
    const { data: transaction, error: txError } = await supabase
      .from('transactions')
      .select('id, member_id, account_type, amount, status')
      .eq('reference', api_ref)
      .maybeSingle()

    if (txError || !transaction) {
      console.error('[WEBHOOK] Transaction not found for ref:', api_ref)
      return new Response(JSON.stringify({ error: 'Transaction not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Ignore if already processed
    if (transaction.status === 'completed') {
      console.log('[WEBHOOK] Already completed, skipping:', api_ref)
      return new Response(JSON.stringify({ success: true, skipped: true }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    if (state === 'COMPLETE') {
      const amount = parseFloat(net_amount ?? transaction.amount)

      // Update transaction to completed
      await supabase
        .from('transactions')
        .update({
          status: 'completed',
          intasend_ref: invoice_id,
          mpesa_ref: mpesa_code ?? null,
          balance_after: amount,
          updated_at: new Date().toISOString(),
        })
        .eq('reference', api_ref)

      // Credit the correct account
      const { memberId, accountType } = {
        memberId: transaction.member_id,
        accountType: transaction.account_type,
      }

      if (accountType === 'fosa') {
        const { data: acc } = await supabase
          .from('fosa_accounts')
          .select('balance')
          .eq('member_id', memberId)
          .single()

        const newBalance = (parseFloat(acc?.balance ?? '0')) + amount
        await supabase
          .from('fosa_accounts')
          .update({ balance: newBalance, updated_at: new Date().toISOString() })
          .eq('member_id', memberId)
      } else {
        const { data: acc } = await supabase
          .from('bosa_accounts')
          .select('savings_balance')
          .eq('member_id', memberId)
          .single()

        const newBalance = (parseFloat(acc?.savings_balance ?? '0')) + amount
        await supabase
          .from('bosa_accounts')
          .update({ savings_balance: newBalance, updated_at: new Date().toISOString() })
          .eq('member_id', memberId)
      }

      console.log(`[WEBHOOK] Deposit completed: ${amount} to ${accountType} for member ${memberId}`)

    } else if (state === 'FAILED') {
      await supabase
        .from('transactions')
        .update({
          status: 'failed',
          intasend_ref: invoice_id,
          updated_at: new Date().toISOString(),
        })
        .eq('reference', api_ref)

      console.log('[WEBHOOK] Deposit failed for ref:', api_ref)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    const err = error as Error
    console.error('[WEBHOOK] Error:', err.message)
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
