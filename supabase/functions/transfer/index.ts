// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { jwtUserId, jsonResponse as json } from '../_shared/auth.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY')!
const INTASEND_BASE = Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'

Deno.serve(async (req: Request) => {
  const userId = jwtUserId(req.headers.get('Authorization'))
  if (!userId) return json({ error: 'Unauthorized' }, 401)

  try {
    const body = await req.json()
    const { type, amount } = body
    if (!amount || amount <= 0) return json({ error: 'Invalid amount' }, 400)

    const { data: member } = await supabase
      .from('members').select('id, full_name, member_number').eq('user_id', userId).single()
    if (!member) return json({ error: 'Member not found' }, 404)

    const { data: fosa } = await supabase
      .from('fosa_accounts').select('id, balance').eq('member_id', member.id).single()
    if (!fosa) return json({ error: 'FOSA account not found' }, 404)

    if (type === 'internal') return await internalTransfer(member, fosa, body)
    if (type === 'external') return await externalTransfer(member, fosa, body)
    return json({ error: 'Invalid transfer type' }, 400)
  } catch (e) {
    console.error('[TRANSFER]', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

async function internalTransfer(fromMember: any, fromFosa: any, body: any) {
  const { to_member_number, amount, note } = body

  const { data: toMember } = await supabase
    .from('members').select('id, full_name').eq('member_number', to_member_number).single()
  if (!toMember) return json({ error: `Member ${to_member_number} not found` }, 404)
  if (toMember.id === fromMember.id) return json({ error: 'Cannot transfer to yourself' }, 400)

  const balance = parseFloat(fromFosa.balance)
  if (amount > balance) return json({ error: `Insufficient balance. Available: KES ${balance.toFixed(2)}` }, 400)

  const { data: toFosa } = await supabase
    .from('fosa_accounts').select('id, balance').eq('member_id', toMember.id).single()
  if (!toFosa) return json({ error: 'Recipient FOSA account not found' }, 404)

  const reference = `TRF-${Date.now()}`
  const newFromBalance = balance - amount
  const newToBalance = parseFloat(toFosa.balance) + amount

  await supabase.from('fosa_accounts').update({ balance: newFromBalance }).eq('id', fromFosa.id)
  await supabase.from('fosa_accounts').update({ balance: newToBalance }).eq('id', toFosa.id)

  await supabase.from('transactions').insert([
    {
      member_id: fromMember.id, account_type: 'fosa', transaction_type: 'transfer',
      amount, balance_before: balance, balance_after: newFromBalance,
      reference, description: `Transfer to ${toMember.full_name} (${to_member_number})${note ? ': ' + note : ''}`,
      status: 'completed',
    },
    {
      member_id: toMember.id, account_type: 'fosa', transaction_type: 'transfer',
      amount, balance_before: parseFloat(toFosa.balance), balance_after: newToBalance,
      reference: `${reference}-IN`, description: `Transfer from ${fromMember.full_name} (${fromMember.member_number})${note ? ': ' + note : ''}`,
      status: 'completed',
    },
  ])

  return json({ success: true, message: `KES ${amount.toFixed(2)} transferred to ${toMember.full_name}` })
}

async function externalTransfer(member: any, fosa: any, body: any) {
  const { bank_code, account_number, account_name, amount } = body

  const balance = parseFloat(fosa.balance)
  if (amount > balance) return json({ error: `Insufficient balance. Available: KES ${balance.toFixed(2)}` }, 400)

  const res = await fetch(`${INTASEND_BASE}/send-money/initiate/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${INTASEND_SECRET}` },
    body: JSON.stringify({
      currency: 'KES', provider: 'PESALINK', requires_approval: 'NO',
      transactions: [{
        name: account_name, account: account_number,
        bank_code, amount: amount.toString(),
        narrative: 'Bank transfer - Omwa Sacco',
      }],
    }),
  })

  const data = await res.json()
  if (!res.ok) return json({ error: data?.errors?.[0]?.detail ?? 'Bank transfer failed' }, 400)

  const reference = `EXT-${Date.now()}`
  const newBalance = balance - amount
  await supabase.from('fosa_accounts').update({ balance: newBalance }).eq('id', fosa.id)
  await supabase.from('transactions').insert({
    member_id: member.id, account_type: 'fosa', transaction_type: 'transfer',
    amount, balance_before: balance, balance_after: newBalance,
    reference, description: `Bank transfer to ${account_name} (${bank_code} ${account_number})`,
    status: 'pending',
  })

  return json({ success: true })
}
