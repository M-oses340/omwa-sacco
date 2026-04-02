// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { jsonResponse as json } from '../_shared/auth.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } }
)

Deno.serve(async (req: Request) => {
  try {
    const payload = await req.json()
    console.log('[WEBHOOK] payload:', JSON.stringify(payload))

    const { invoice_id, state, api_ref, net_amount, value } = payload

    if (!api_ref) return json({ received: true })

    // api_ref format: DEP-{timestamp} or {memberId}:fosa:{txId}
    const amount = parseFloat(net_amount ?? value ?? '0')

    if (state === 'COMPLETE') {
      // Find transaction by reference or intasend_ref
      const { data: tx } = await supabase
        .from('transactions')
        .select('id, member_id, account_type, amount, balance_before')
        .or(`reference.eq.${api_ref},intasend_ref.eq.${invoice_id}`)
        .single()

      if (tx) {
        const newBalance = parseFloat(tx.balance_before ?? '0') + (amount || tx.amount)

        await supabase.from('transactions').update({
          status: 'completed',
          balance_after: newBalance,
          intasend_ref: invoice_id,
          updated_at: new Date().toISOString(),
        }).eq('id', tx.id)

        // Credit the FOSA account
        if (tx.account_type === 'fosa') {
          await supabase.from('fosa_accounts')
            .update({ balance: newBalance, updated_at: new Date().toISOString() })
            .eq('member_id', tx.member_id)
        }

        console.log('[WEBHOOK] Credited', newBalance, 'to member', tx.member_id)
      }
    } else if (state === 'FAILED' || state === 'CANCELLED') {
      await supabase.from('transactions')
        .update({ status: 'failed', updated_at: new Date().toISOString() })
        .or(`reference.eq.${api_ref},intasend_ref.eq.${invoice_id}`)
    }

    return json({ received: true })
  } catch (e) {
    console.error('[WEBHOOK]', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})
