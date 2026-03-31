import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY')!
const INTASEND_BASE = Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Unauthorized' }, 401)

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const body = await req.json()
    const { type, amount } = body

    if (!amount || amount <= 0) return json({ error: 'Invalid amount' }, 400)

    // Get sender member + FOSA balance
    const { data: sender } = await supabase
      .from('members')
      .select('id, full_name, member_number')
      .eq('user_id', user.id)
      .single()

    if (!sender) return json({ error: 'Member not found' }, 404)

    const { data: senderFosa } = await supabase
      .from('fosa_accounts')
      .select('id, balance')
      .eq('member_id', sender.id)
      .single()

    if (!senderFosa) return json({ error: 'FOSA account not found' }, 404)

    const balance = parseFloat(senderFosa.balance)
    if (amount > balance) {
      return json({
        error: `Insufficient balance. Available: KES ${balance.toFixed(2)}`,
      }, 400)
    }

    const reference = `TRF-${Date.now()}`
    const newBalance = balance - amount

    if (type === 'internal') {
      const { to_member_number, note } = body

      // Find recipient
      const { data: recipient } = await supabase
        .from('members')
        .select('id, full_name')
        .eq('member_number', to_member_number.toUpperCase())
        .maybeSingle()

      if (!recipient) {
        return json({ error: `Member ${to_member_number} not found` }, 404)
      }

      const { data: recipientFosa } = await supabase
        .from('fosa_accounts')
        .select('id, balance')
        .eq('member_id', recipient.id)
        .single()

      if (!recipientFosa) {
        return json({ error: 'Recipient has no FOSA account' }, 404)
      }

      const recipientNewBalance = parseFloat(recipientFosa.balance) + amount

      // Atomic transfer
      await Promise.all([
        supabase.from('fosa_accounts')
          .update({ balance: newBalance, updated_at: new Date().toISOString() })
          .eq('id', senderFosa.id),
        supabase.from('fosa_accounts')
          .update({ balance: recipientNewBalance, updated_at: new Date().toISOString() })
          .eq('id', recipientFosa.id),
        supabase.from('transactions').insert([
          {
            member_id: sender.id,
            account_type: 'fosa',
            transaction_type: 'transfer',
            amount,
            balance_before: balance,
            balance_after: newBalance,
            reference,
            description: `Transfer to ${recipient.full_name} (${to_member_number})${note ? ': ' + note : ''}`,
            status: 'completed',
          },
          {
            member_id: recipient.id,
            account_type: 'fosa',
            transaction_type: 'transfer',
            amount,
            balance_before: parseFloat(recipientFosa.balance),
            balance_after: recipientNewBalance,
            reference: `${reference}-IN`,
            description: `Transfer from ${sender.full_name} (${sender.member_number})${note ? ': ' + note : ''}`,
            status: 'completed',
          },
        ]),
      ])

      return json({ success: true })
    } else {
      // External bank transfer via IntaSend
      const { bank_code, account_number, account_name } = body

      if (!bank_code || !account_number || !account_name) {
        return json({ error: 'Bank code, account number and name are required' }, 400)
      }

      const res = await fetch(`${INTASEND_BASE}/send-money/initiate/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${INTASEND_SECRET}`,
        },
        body: JSON.stringify({
          currency: 'KES',
          provider: 'PESALINK',
          requires_approval: 'NO',
          transactions: [{
            name: account_name,
            account: account_number,
            bank_code,
            amount: amount.toString(),
            narrative: 'FOSA bank transfer - Omwa Sacco',
          }],
        }),
      })

      const data = await res.json()
      console.log('[TRANSFER] IntaSend response:', JSON.stringify(data))

      if (!res.ok) {
        const errMsg = data?.errors?.[0]?.detail ?? 'Bank transfer failed'
        return json({ error: errMsg }, 400)
      }

      // Deduct balance and record
      await supabase.from('fosa_accounts')
        .update({ balance: newBalance, updated_at: new Date().toISOString() })
        .eq('id', senderFosa.id)

      await supabase.from('transactions').insert({
        member_id: sender.id,
        account_type: 'fosa',
        transaction_type: 'transfer',
        amount,
        balance_before: balance,
        balance_after: newBalance,
        reference,
        description: `Bank transfer to ${account_name} - ${account_number}`,
        status: 'pending',
      })

      return json({ success: true })
    }
  } catch (e) {
    console.error('[TRANSFER] Error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
