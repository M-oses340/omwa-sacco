import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// @deno-types="npm:intasend-node"
import IntaSend from 'npm:intasend-node'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  try {
    // Verify auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Unauthorized' }, 401)

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const { amount, phone, method } = await req.json()

    if (!amount || amount < 100) {
      return json({ error: 'Minimum withdrawal is KES 100' }, 400)
    }
    if (method === 'mpesa' && !phone) {
      return json({ error: 'Phone number required for M-Pesa withdrawal' }, 400)
    }

    // Get member
    const { data: member } = await supabase
      .from('members')
      .select('id, full_name')
      .eq('user_id', user.id)
      .single()

    if (!member) return json({ error: 'Member not found' }, 404)

    // Get FOSA account and check balance
    const { data: fosa } = await supabase
      .from('fosa_accounts')
      .select('id, balance')
      .eq('member_id', member.id)
      .single()

    if (!fosa) return json({ error: 'FOSA account not found' }, 404)

    const balance = parseFloat(fosa.balance)
    if (amount > balance) {
      return json({
        error: `Insufficient balance. Available: KES ${balance.toFixed(2)}`,
      }, 400)
    }

    const reference = `WDR-${Date.now()}`
    const newBalance = balance - amount

    if (method === 'mpesa') {
      // Normalise phone to 254XXXXXXXXX
      const normalised = phone.startsWith('+')
        ? phone.slice(1)
        : phone.startsWith('0')
        ? `254${phone.slice(1)}`
        : phone

      const isSandbox = Deno.env.get('INTASEND_SANDBOX') === 'true'
      const intasend = new IntaSend(
        Deno.env.get('INTASEND_PUBLISHABLE_KEY')!,
        Deno.env.get('INTASEND_SECRET_KEY')!,
        isSandbox
      )

      const payouts = intasend.payouts()

      console.log('[WITHDRAWAL] Initiating M-Pesa B2C to', normalised, 'amount', amount)

      const response = await payouts.mpesa({
        currency: 'KES',
        requires_approval: 'NO',
        transactions: [{
          name: member.full_name,
          account: normalised,
          amount: amount.toString(),
          narrative: 'FOSA withdrawal - Omwa Sacco',
        }],
      })

      console.log('[WITHDRAWAL] IntaSend response:', JSON.stringify(response))

      // Deduct balance and record transaction
      await supabase
        .from('fosa_accounts')
        .update({ balance: newBalance, updated_at: new Date().toISOString() })
        .eq('id', fosa.id)

      await supabase.from('transactions').insert({
        member_id: member.id,
        account_type: 'fosa',
        transaction_type: 'withdrawal',
        amount,
        balance_before: balance,
        balance_after: newBalance,
        reference,
        description: `M-Pesa withdrawal to ${phone}`,
        status: 'pending',
      })

      return json({ success: true })
    } else {
      // ATM — deduct immediately
      await supabase
        .from('fosa_accounts')
        .update({ balance: newBalance, updated_at: new Date().toISOString() })
        .eq('id', fosa.id)

      await supabase.from('transactions').insert({
        member_id: member.id,
        account_type: 'fosa',
        transaction_type: 'withdrawal',
        amount,
        balance_before: balance,
        balance_after: newBalance,
        reference,
        description: 'ATM withdrawal',
        status: 'completed',
      })

      return json({ success: true })
    }
  } catch (e) {
    console.error('[WITHDRAWAL] Error:', e.message, e.stack)
    return json({ error: e.message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
