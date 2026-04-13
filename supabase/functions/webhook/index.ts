// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { jsonResponse as json } from '../_shared/auth.ts'
import { notify } from '../notifications/index.ts'

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

    if (!api_ref && !invoice_id) return json({ received: true })

    const amount = parseFloat(net_amount ?? value ?? '0')

    // Find the transaction by reference (deposits) or intasend_ref (B2C withdrawals)
    const orFilter = [
      api_ref ? `reference.eq.${api_ref}` : null,
      invoice_id ? `intasend_ref.eq.${invoice_id}` : null,
    ].filter(Boolean).join(',')

    const { data: tx } = await supabase
      .from('transactions')
      .select('id, member_id, account_type, transaction_type, amount, balance_before, balance_after')
      .or(orFilter)
      .maybeSingle()

    if (!tx) {
      console.log('[WEBHOOK] No matching transaction for', api_ref ?? invoice_id)
      return json({ received: true })
    }

    const isWithdrawal = tx.transaction_type === 'withdrawal' || tx.transaction_type === 'scheduled_payment'

    if (state === 'COMPLETE') {
      if (isWithdrawal) {
        // Balance was already deducted at approval — just mark completed
        await supabase.from('transactions').update({
          status: 'completed',
          intasend_ref: invoice_id,
          updated_at: new Date().toISOString(),
        }).eq('id', tx.id)
        console.log('[WEBHOOK] Withdrawal completed for member', tx.member_id)
      } else {
        // Deposit — credit the account
        const newBalance = parseFloat(tx.balance_before ?? '0') + (amount || tx.amount)
        await supabase.from('transactions').update({
          status: 'completed',
          balance_after: newBalance,
          intasend_ref: invoice_id,
          updated_at: new Date().toISOString(),
        }).eq('id', tx.id)
        if (tx.account_type === 'fosa') {
          await supabase.from('fosa_accounts')
            .update({ balance: newBalance, updated_at: new Date().toISOString() })
            .eq('member_id', tx.member_id)
        }
        console.log('[WEBHOOK] Deposit credited', newBalance, 'to member', tx.member_id)
        await notify(tx.member_id, 'deposit',
          'Deposit Confirmed ✅',
          `KES ${(amount || tx.amount).toLocaleString()} has been credited to your FOSA account. New balance: KES ${newBalance.toLocaleString()}.`,
          { type: 'deposit', amount: String(amount || tx.amount) }
        )
      }
    } else if (state === 'FAILED' || state === 'CANCELLED') {
      await supabase.from('transactions').update({
        status: 'failed',
        updated_at: new Date().toISOString(),
      }).eq('id', tx.id)

      // Reversal — refund balance if withdrawal failed after deduction
      if (isWithdrawal) {
        const refundBalance = parseFloat(tx.balance_before ?? '0')
        await supabase.from('fosa_accounts')
          .update({ balance: refundBalance, updated_at: new Date().toISOString() })
          .eq('member_id', tx.member_id)
        console.log('[WEBHOOK] Withdrawal failed — refunded', refundBalance, 'to member', tx.member_id)
        await notify(tx.member_id, 'withdrawal',
          'Withdrawal Failed ❌',
          `Your withdrawal of KES ${tx.amount.toLocaleString()} could not be processed. Your balance has been restored.`,
          { type: 'withdrawal_failed' }
        )
      }
    }

    return json({ received: true })
  } catch (e) {
    console.error('[WEBHOOK]', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})
