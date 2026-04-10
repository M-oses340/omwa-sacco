// deno-lint-ignore-file no-explicit-any
import { getAuthUserId, jsonResponse } from '../_shared/auth.ts'
import { dbSelect, dbInsert, dbUpdate } from '../_shared/db.ts'

Deno.serve(async (req: Request) => {
  // Always return JSON — never let an unhandled error bubble up as HTML
  try {
    return await _handle(req)
  } catch (e) {
    console.error('[PAY-BILLS] unhandled:', (e as Error).message)
    return jsonResponse({ error: (e as Error).message }, 500)
  }
})

async function _handle(req: Request): Promise<Response> {
  let body: any
  try { body = JSON.parse(await req.text()) } catch { return jsonResponse({ error: 'bad json' }, 400) }

  const uid = await getAuthUserId(req, body?.jwt)
  if (!uid) return jsonResponse({ error: 'Unauthorized' }, 401)

  const IS  = Deno.env.get('INTASEND_SECRET_KEY')!
  const IB  = Deno.env.get('INTASEND_SANDBOX') === 'true'
    ? 'https://sandbox.intasend.com/api/v1'
    : 'https://payment.intasend.com/api/v1'

  try {
    // ── Resolve member & FOSA ──────────────────────────────────────────────
    const members = await dbSelect('members', `user_id=eq.${uid}&select=id,full_name,status&limit=1`)
    const member  = members[0]
    if (!member)              return jsonResponse({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return jsonResponse({ error: 'Account not active' }, 403)

    const fosas = await dbSelect('fosa_accounts', `member_id=eq.${member.id}&select=id,balance&limit=1`)
    const fosa  = fosas[0]
    if (!fosa) return jsonResponse({ error: 'FOSA account not found' }, 404)

    const { action, amount } = body
    if (!amount || amount <= 0) return jsonResponse({ error: 'Invalid amount' })

    const balance = parseFloat(fosa.balance)
    if (amount > balance) {
      return jsonResponse({ error: `Insufficient FOSA balance. Available: KES ${balance.toFixed(2)}` })
    }

    // ── Build IntaSend B2B transaction item ────────────────────────────────
    let txItem: any
    let ref: string
    let description: string

    if (action === 'paybill') {
      const { business_number, account_number } = body
      if (!business_number || !account_number) {
        return jsonResponse({ error: 'business_number and account_number are required' })
      }
      ref         = `PBL-${Date.now()}`
      description = `Paybill ${business_number} / Acc ${account_number}`
      txItem = {
        name:              `Paybill ${business_number}`,
        account:           business_number,
        account_type:      'PayBill',
        account_reference: account_number,
        amount,
        narrative:         `Omwa Sacco - ${ref}`,
      }
    } else if (action === 'till') {
      const { till_number } = body
      if (!till_number) return jsonResponse({ error: 'till_number is required' })
      ref         = `TLL-${Date.now()}`
      description = `Till payment to ${till_number}`
      txItem = {
        name:         `Till ${till_number}`,
        account:      till_number,
        account_type: 'TillNumber',
        amount,
        narrative:    `Omwa Sacco - ${ref}`,
      }
    } else {
      return jsonResponse({ error: 'Invalid action. Use paybill or till' })
    }

    // ── Record pending transaction ─────────────────────────────────────────
    const tx = await dbInsert('transactions', {
      member_id:        member.id,
      account_type:     'fosa',
      transaction_type: 'paybill',
      amount,
      balance_before:   balance,
      reference:        ref,
      description,
      status:           'pending',
    })
    if (!tx?.id) return jsonResponse({ error: 'Failed to record transaction' }, 500)

    // ── Step 1: Initiate IntaSend B2B (auto-approve — no second step needed) ─
    const initiateRes = await fetch(`${IB}/send-money/initiate/`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${IS}` },
      body:    JSON.stringify({
        currency:          'KES',
        provider:          'MPESA-B2B',
        requires_approval: 'NO',
        transactions:      [txItem],
      }),
    })
    const initiateData = await initiateRes.json()
    console.log('[PAY-BILLS] initiate', initiateRes.status, JSON.stringify(initiateData))

    if (!initiateRes.ok) {
      await dbUpdate('transactions', `id=eq.${tx.id}`, { status: 'failed' })
      const errMsg = initiateData?.errors?.[0]?.detail ?? initiateData?.detail ?? 'Payment initiation failed'
      return jsonResponse({ error: errMsg })
    }

    // ── Deduct FOSA balance (initiate succeeded, no approve step) ──────────
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
      message: `Payment of KES ${amount.toFixed(2)} to ${txItem.name} is processing. You will receive an M-Pesa confirmation shortly.`,
    })

  } catch (e) {
    console.error('[PAY-BILLS]', (e as Error).message)
    return jsonResponse({ error: (e as Error).message }, 500)
  }
}
