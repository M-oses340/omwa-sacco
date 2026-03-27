import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createHmac } from 'https://deno.land/std@0.177.0/node/crypto.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const WEBHOOK_SECRET = Deno.env.get('INTASEND_WEBHOOK_SECRET')!

function validateSignature(payload: string, signature: string): boolean {
  const hmac = createHmac('sha256', WEBHOOK_SECRET)
  hmac.update(payload)
  const expected = hmac.digest('hex')
  return expected === signature
}

Deno.serve(async (req) => {
  try {
    const rawBody = await req.text()

    // Validate webhook signature
    const signature = req.headers.get('x-intasend-signature') ?? ''
    if (WEBHOOK_SECRET && signature && !validateSignature(rawBody, signature)) {
      console.error('[WEBHOOK] Invalid signature')
      return new Response(JSON.stringify({ error: 'Invalid signature' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const payload = JSON.parse(rawBody)
    const { invoice_id, state, net_amount, api_ref, mpesa_code } = payload

    console.log(`[WEBHOOK] Received: state=${state}, api_ref=${api_ref}`)

    // api_ref format: "memberId:accountType:transactionId"
    const parts = (api_ref ?? '').split(':')
    if (parts.length !== 3) {
      return new Response(JSON.stringify({ error: 'Invalid api_ref' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const [memberId, accountType, transactionId] = parts
    const amount = parseFloat(net_amount ?? '0')

    if (state === 'COMPLETE') {
      // Fetch current FOSA balance
      const { data: fosa, error: fosaErr } = await supabase
        .from('fosa_accounts')
        .select('balance')
        .eq('member_id', memberId)
        .single()

      if (fosaErr || !fosa) {
        console.error('[WEBHOOK] FOSA account not found:', fosaErr?.message)
        return new Response(JSON.stringify({ error: 'Account not found' }), {
          status: 404,
        })
      }

      const newBalance = (parseFloat(fosa.balance) ?? 0) + amount

      // Credit FOSA account
      await supabase
        .from('fosa_accounts')
        .update({ balance: newBalance, updated_at: new Date().toISOString() })
        .eq('member_id', memberId)

      // Update transaction to completed
      await supabase
        .from('transactions')
        .update({
          status: 'completed',
          balance_after: newBalance,
          intasend_ref: invoice_id,
          mpesa_ref: mpesa_code,
          updated_at: new Date().toISOString(),
        })
        .eq('id', transactionId)

      console.log(`[WEBHOOK] FOSA credited KES ${amount} for member ${memberId}`)

    } else if (state === 'FAILED') {
      await supabase
        .from('transactions')
        .update({
          status: 'failed',
          intasend_ref: invoice_id,
          updated_at: new Date().toISOString(),
        })
        .eq('id', transactionId)

      console.log(`[WEBHOOK] Payment failed for transaction ${transactionId}`)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('[WEBHOOK] Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
