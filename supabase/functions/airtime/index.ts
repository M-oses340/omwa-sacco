// deno-lint-ignore-file no-explicit-any
import { getAuthUserId, jsonResponse } from '../_shared/auth.ts'
import { dbSelect, dbInsert, dbUpdate } from '../_shared/db.ts'

// Network → M-Pesa paybill number for airtime top-up
const AIRTIME_PAYBILLS: Record<string, string> = {
  'Safaricom': '220220',
  'Airtel':    '220220',
  'Telkom':    '220220',
}

Deno.serve(async (req: Request) => {
  try {
    return await _handle(req)
  } catch (e) {
    console.error('[AIRTIME] unhandled:', (e as Error).message)
    return jsonResponse({ error: (e as Error).message }, 500)
  }
})

async function _handle(req: Request): Promise<Response> {
  let body: any
  try { body = JSON.parse(await req.text()) } catch { return jsonResponse({ error: 'bad json' }, 400) }

  const uid = await getAuthUserId(req, body?.jwt)
  if (!uid) return jsonResponse({ error: 'Unauthorized' }, 401)

  const IS = Deno.env.get('INTASEND_SECRET_KEY')!
  const IB = Deno.env.get('INTASEND_SANDBOX') === 'true'
    ? 'https://sandbox.intasend.com/api/v1'
    : 'https://payment.intasend.com/api/v1'

  // ── Resolve member & FOSA ────────────────────────────────────────────────
  const members = await dbSelect('members', `user_id=eq.${uid}&select=id,full_name,status&limit=1`)
  const member  = members[0]
  if (!member)                   return jsonResponse({ error: 'Member not found' }, 404)
  if (member.status !== 'active') return jsonResponse({ error: 'Account not active' }, 403)

  const fosas = await dbSelect('fosa_accounts', `member_id=eq.${member.id}&select=id,balance&limit=1`)
  const fosa  = fosas[0]
  if (!fosa) return jsonResponse({ error: 'FOSA account not found' }, 404)

  const { phone_number, network, amount } = body
  if (!phone_number) return jsonResponse({ error: 'phone_number is required' })
  if (!network)      return jsonResponse({ error: 'network is required' })
  if (!amount || amount < 10) return jsonResponse({ error: 'Minimum airtime is KES 10' })

  const balance = parseFloat(fosa.balance)
  if (amount > balance) {
    return jsonResponse({ error: `Insufficient FOSA balance. Available: KES ${balance.toFixed(2)}` })
  }

  // Normalise phone to 07XXXXXXXX or 01XXXXXXXX (account reference for paybill)
  const phone = phone_number.toString().replace(/^\+254/, '0').replace(/^254/, '0')

  const paybill = AIRTIME_PAYBILLS[network]
  if (!paybill) return jsonResponse({ error: `Unsupported network: ${network}` })

  const ref = `AIR-${Date.now()}`

  // ── Record pending transaction ───────────────────────────────────────────
  const tx = await dbInsert('transactions', {
    member_id:        member.id,
    account_type:     'fosa',
    transaction_type: 'airtime',
    amount,
    balance_before:   balance,
    reference:        ref,
    description:      `${network} airtime for ${phone}`,
    status:           'pending',
  })
  if (!tx?.id) return jsonResponse({ error: 'Failed to record transaction' }, 500)

  // ── IntaSend B2B — airtime via paybill ───────────────────────────────────
  const initiateRes = await fetch(`${IB}/send-money/initiate/`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${IS}` },
    body:    JSON.stringify({
      currency:          'KES',
      provider:          'MPESA-B2B',
      requires_approval: 'NO',
      transactions: [{
        name:              `${network} Airtime`,
        account:           paybill,
        account_type:      'PayBill',
        account_reference: phone,
        amount,
        narrative:         `Airtime ${phone} - ${ref}`,
      }],
    }),
  })

  const initiateText = await initiateRes.text()
  console.log('[AIRTIME] initiate', initiateRes.status, initiateText.substring(0, 300))

  let initiateData: any = {}
  try { initiateData = JSON.parse(initiateText) } catch { /* non-JSON */ }

  if (!initiateRes.ok) {
    await dbUpdate('transactions', `id=eq.${tx.id}`, { status: 'failed' })
    const errMsg = initiateData?.errors?.[0]?.detail ?? initiateData?.detail ?? 'Airtime purchase failed'
    return jsonResponse({ error: errMsg })
  }

  // ── Deduct FOSA balance ──────────────────────────────────────────────────
  const newBalance = balance - amount
  await dbUpdate('fosa_accounts', `id=eq.${fosa.id}`, {
    balance:    newBalance,
    updated_at: new Date().toISOString(),
  })
  await dbUpdate('transactions', `id=eq.${tx.id}`, {
    balance_after: newBalance,
    intasend_ref:  initiateData.file_id ?? initiateData.tracking_id,
    status:        'pending', // webhook will mark completed
  })

  return jsonResponse({
    success: true,
    message: `KES ${amount.toFixed(2)} ${network} airtime for ${phone} is processing.`,
  })
}
