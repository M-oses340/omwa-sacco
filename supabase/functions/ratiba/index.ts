// deno-lint-ignore-file no-explicit-any
// Ratiba — scheduled / recurring payment management
// Deducts from member FOSA and sends to a destination via IntaSend:
//   mpesa    → MPESA-B2C  (phone number)
//   paybill  → MPESA-B2B  (business number + account ref)
//   till     → MPESA-B2B  (till number)
//   pesalink → PESALINK   (bank account)

import { getAuthUserId, jsonResponse as R } from '../_shared/auth.ts'
import { dbSelect, dbInsert, dbUpdate } from '../_shared/db.ts'

const IB = Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'
const IS = Deno.env.get('INTASEND_SECRET_KEY')!
const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? ''

Deno.serve(async (req: Request) => {
  try { return await handle(req) }
  catch (e) {
    console.error('[RATIBA] unhandled:', (e as Error).message)
    return R({ error: (e as Error).message }, 500)
  }
})

async function handle(req: Request): Promise<Response> {
  let body: any
  try { body = JSON.parse(await req.text()) } catch { return R({ error: 'bad json' }, 400) }

  const { action } = body

  if (action === 'run') {
    const cronKey = req.headers.get('x-cron-secret') ?? body.cron_secret ?? ''
    if (!CRON_SECRET || cronKey !== CRON_SECRET) return R({ error: 'Forbidden' }, 403)
    return await runDueSchedules()
  }

  const uid = await getAuthUserId(req, body?.jwt)
  if (!uid) return R({ error: 'Unauthorized' }, 401)

  const members = await dbSelect('members', `user_id=eq.${uid}&select=id,full_name,phone_number,status&limit=1`)
  const member = members[0]
  if (!member) return R({ error: 'Member not found' }, 404)
  if (member.status !== 'active') return R({ error: 'Account not active' }, 403)

  switch (action) {
    case 'create': return await createSchedule(member, body)
    case 'list':   return await listSchedules(member)
    case 'update': return await updateSchedule(member, body)
    case 'cancel': return await cancelSchedule(member, body)
    default:       return R({ error: 'Invalid action. Use: create, list, update, cancel, run' }, 400)
  }
}

// ── Create ────────────────────────────────────────────────────────────────────
async function createSchedule(member: any, body: any): Promise<Response> {
  const {
    payment_type, amount, frequency, next_run_date, description,
    destination_type = 'mpesa', destination_account, destination_name, destination_ref,
  } = body

  if (!payment_type) return R({ error: 'payment_type is required' }, 400)
  if (!amount || amount <= 0) return R({ error: 'amount must be > 0' }, 400)
  if (!frequency) return R({ error: 'frequency is required (daily, weekly, monthly)' }, 400)
  if (!next_run_date) return R({ error: 'next_run_date is required (YYYY-MM-DD)' }, 400)

  const validTypes = ['savings', 'loan_repayment', 'shares']
  if (!validTypes.includes(payment_type))
    return R({ error: `payment_type must be one of: ${validTypes.join(', ')}` }, 400)

  const validFreqs = ['daily', 'weekly', 'monthly']
  if (!validFreqs.includes(frequency))
    return R({ error: `frequency must be one of: ${validFreqs.join(', ')}` }, 400)

  const validDest = ['mpesa', 'paybill', 'till', 'pesalink']
  if (!validDest.includes(destination_type))
    return R({ error: `destination_type must be one of: ${validDest.join(', ')}` }, 400)

  if (!destination_account)
    return R({ error: 'destination_account is required (phone / till / business / bank account number)' }, 400)

  if (destination_type === 'paybill' && !destination_ref)
    return R({ error: 'destination_ref (account reference) is required for paybill' }, 400)

  const schedule = await dbInsert('scheduled_payments', {
    member_id:           member.id,
    payment_type,
    amount,
    frequency,
    next_run_date,
    description:         description ?? `${payment_type} - ${frequency}`,
    status:              'active',
    destination_type,
    destination_account,
    destination_name:    destination_name ?? '',
    destination_ref:     destination_ref ?? null,
  })

  return R({ success: true, schedule })
}

// ── List ──────────────────────────────────────────────────────────────────────
async function listSchedules(member: any): Promise<Response> {
  const schedules = await dbSelect(
    'scheduled_payments',
    `member_id=eq.${member.id}&order=created_at.desc&select=*`,
  )
  return R({ schedules })
}

// ── Update ────────────────────────────────────────────────────────────────────
async function updateSchedule(member: any, body: any): Promise<Response> {
  const { schedule_id, amount, frequency, next_run_date, description, status,
          destination_type, destination_account, destination_name, destination_ref } = body
  if (!schedule_id) return R({ error: 'schedule_id is required' }, 400)

  const rows = await dbSelect('scheduled_payments', `id=eq.${schedule_id}&member_id=eq.${member.id}&limit=1`)
  if (!rows[0]) return R({ error: 'Schedule not found' }, 404)

  const patch: any = { updated_at: new Date().toISOString() }
  if (amount !== undefined)              patch.amount              = amount
  if (frequency !== undefined)           patch.frequency           = frequency
  if (next_run_date !== undefined)       patch.next_run_date       = next_run_date
  if (description !== undefined)         patch.description         = description
  if (status !== undefined)              patch.status              = status
  if (destination_type !== undefined)    patch.destination_type    = destination_type
  if (destination_account !== undefined) patch.destination_account = destination_account
  if (destination_name !== undefined)    patch.destination_name    = destination_name
  if (destination_ref !== undefined)     patch.destination_ref     = destination_ref

  await dbUpdate('scheduled_payments', `id=eq.${schedule_id}`, patch)
  return R({ success: true })
}

// ── Cancel ────────────────────────────────────────────────────────────────────
async function cancelSchedule(member: any, body: any): Promise<Response> {
  const { schedule_id } = body
  if (!schedule_id) return R({ error: 'schedule_id is required' }, 400)

  const rows = await dbSelect('scheduled_payments', `id=eq.${schedule_id}&member_id=eq.${member.id}&limit=1`)
  if (!rows[0]) return R({ error: 'Schedule not found' }, 404)

  await dbUpdate('scheduled_payments', `id=eq.${schedule_id}`, {
    status: 'cancelled', updated_at: new Date().toISOString(),
  })
  return R({ success: true })
}

// ── Run due schedules (cron) ──────────────────────────────────────────────────
async function runDueSchedules(): Promise<Response> {
  const today = new Date().toISOString().split('T')[0]
  const due = await dbSelect('scheduled_payments', `status=eq.active&next_run_date=lte.${today}&select=*`)
  console.log(`[RATIBA] ${due.length} schedule(s) due on ${today}`)

  const results: any[] = []
  for (const schedule of due) {
    try {
      results.push({ schedule_id: schedule.id, ...await processSchedule(schedule) })
    } catch (e) {
      console.error(`[RATIBA] schedule ${schedule.id} error:`, (e as Error).message)
      results.push({ schedule_id: schedule.id, success: false, error: (e as Error).message })
    }
  }
  return R({ processed: results.length, results })
}

// ── Process a single schedule ─────────────────────────────────────────────────
async function processSchedule(schedule: any): Promise<{ success: boolean; error?: string }> {
  const members = await dbSelect('members', `id=eq.${schedule.member_id}&select=id,full_name,phone_number,status&limit=1`)
  const member = members[0]
  if (!member || member.status !== 'active') {
    await pauseSchedule(schedule.id, 'Member inactive')
    return { success: false, error: 'Member inactive' }
  }

  const fosas = await dbSelect('fosa_accounts', `member_id=eq.${member.id}&select=id,balance&limit=1`)
  const fosa = fosas[0]
  if (!fosa) {
    await pauseSchedule(schedule.id, 'FOSA not found')
    return { success: false, error: 'FOSA not found' }
  }

  const balance = parseFloat(fosa.balance)
  const amount  = parseFloat(schedule.amount)

  if (amount > balance) {
    console.warn(`[RATIBA] Insufficient balance for ${schedule.id}: need ${amount}, have ${balance}`)
    await advanceNextRun(schedule)
    return { success: false, error: `Insufficient FOSA balance (${balance.toFixed(2)})` }
  }

  const ref = `RTB-${schedule.id.slice(0, 8)}-${Date.now()}`
  const destType: string = schedule.destination_type ?? 'mpesa'
  const destAccount: string = schedule.destination_account ?? ''
  const destName: string = schedule.destination_name || member.full_name
  const destRef: string = schedule.destination_ref ?? ''

  // ── Build IntaSend payload based on destination type ─────────────────────
  let provider: string
  let txItem: any

  if (destType === 'mpesa') {
    // B2C — send to M-Pesa phone number
    let phone = destAccount.replace(/\D/g, '')
    if (phone.startsWith('0')) phone = `254${phone.slice(1)}`
    if (phone.startsWith('+')) phone = phone.slice(1)
    provider = 'MPESA-B2C'
    txItem = {
      name:      destName,
      account:   phone,
      amount:    amount.toString(),
      narrative: `Omwa Sacco - ${schedule.payment_type} - ${ref}`,
    }
  } else if (destType === 'paybill') {
    // B2B PayBill
    provider = 'MPESA-B2B'
    txItem = {
      name:              destName,
      account:           destAccount,
      account_type:      'PayBill',
      account_reference: destRef,
      amount,
      narrative:         `Omwa Sacco - ${ref}`,
    }
  } else if (destType === 'till') {
    // B2B Till
    provider = 'MPESA-B2B'
    txItem = {
      name:         destName,
      account:      destAccount,
      account_type: 'TillNumber',
      amount,
      narrative:    `Omwa Sacco - ${ref}`,
    }
  } else if (destType === 'pesalink') {
    // PesaLink bank transfer — destination_account = bank account, destination_ref = bank_code
    provider = 'PESALINK'
    txItem = {
      name:      destName,
      account:   destAccount,
      bank_code: destRef,
      amount:    amount.toString(),
      narrative: `Omwa Sacco - ${schedule.payment_type} - ${ref}`,
    }
  } else {
    return { success: false, error: `Unknown destination_type: ${destType}` }
  }

  // ── Record pending transaction ────────────────────────────────────────────
  const tx = await dbInsert('transactions', {
    member_id:            member.id,
    account_type:         'fosa',
    transaction_type:     'scheduled_payment',
    amount,
    balance_before:       balance,
    reference:            ref,
    description:          `${schedule.description ?? schedule.payment_type} → ${destName} (${destAccount})`,
    status:               'pending',
    scheduled_payment_id: schedule.id,
  })
  if (!tx?.id) return { success: false, error: 'Failed to record transaction' }

  // ── Deduct FOSA balance ───────────────────────────────────────────────────
  const newBalance = balance - amount
  await dbUpdate('fosa_accounts', `id=eq.${fosa.id}`, {
    balance: newBalance, updated_at: new Date().toISOString(),
  })

  // ── Fire IntaSend transfer ────────────────────────────────────────────────
  const intaRes = await fetch(`${IB}/send-money/initiate/`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${IS}` },
    body:    JSON.stringify({
      currency: 'KES', provider, requires_approval: 'NO', transactions: [txItem],
    }),
  })
  const intaData = await intaRes.json()
  console.log(`[RATIBA] IntaSend ${provider} ${intaRes.status}:`, JSON.stringify(intaData))

  if (!intaRes.ok) {
    // Rollback
    await dbUpdate('fosa_accounts', `id=eq.${fosa.id}`, {
      balance: balance, updated_at: new Date().toISOString(),
    })
    await dbUpdate('transactions', `id=eq.${tx.id}`, { status: 'failed' })
    return { success: false, error: intaData?.errors?.[0]?.detail ?? `IntaSend ${provider} failed` }
  }

  await dbUpdate('transactions', `id=eq.${tx.id}`, {
    balance_after: newBalance,
    intasend_ref:  intaData.file_id ?? intaData.tracking_id ?? null,
    status:        'pending',
  })

  await advanceNextRun(schedule)
  return { success: true }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function nextRunDate(currentDate: string, frequency: string): string {
  const d = new Date(currentDate)
  if (frequency === 'daily')   d.setDate(d.getDate() + 1)
  if (frequency === 'weekly')  d.setDate(d.getDate() + 7)
  if (frequency === 'monthly') d.setMonth(d.getMonth() + 1)
  return d.toISOString().split('T')[0]
}

async function advanceNextRun(schedule: any): Promise<void> {
  const today = new Date().toISOString().split('T')[0]
  await dbUpdate('scheduled_payments', `id=eq.${schedule.id}`, {
    last_run_date: today,
    next_run_date: nextRunDate(schedule.next_run_date, schedule.frequency),
    updated_at:    new Date().toISOString(),
  })
}

async function pauseSchedule(id: string, reason: string): Promise<void> {
  console.warn(`[RATIBA] Pausing ${id}: ${reason}`)
  await dbUpdate('scheduled_payments', `id=eq.${id}`, {
    status: 'paused', updated_at: new Date().toISOString(),
  })
}
