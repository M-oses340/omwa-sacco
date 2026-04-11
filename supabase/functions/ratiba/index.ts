// deno-lint-ignore-file no-explicit-any
// Ratiba — scheduled / recurring payment management
// Deductions come from the member's FOSA account via IntaSend B2C (M-Pesa)
//
// Actions (member-facing):
//   create  — set up a new recurring payment
//   list    — list own schedules
//   update  — change amount / frequency / next_run_date
//   cancel  — cancel a schedule
//
// Actions (cron / admin):
//   run     — process all due schedules (called by pg_cron or a cron job)

import { getAuthUserId, jsonResponse as R } from '../_shared/auth.ts'
import { dbSelect, dbInsert, dbUpdate } from '../_shared/db.ts'

const IB = Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'
const IS = Deno.env.get('INTASEND_SECRET_KEY')!
const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? ''

Deno.serve(async (req: Request) => {
  try {
    return await handle(req)
  } catch (e) {
    console.error('[RATIBA] unhandled:', (e as Error).message)
    return R({ error: (e as Error).message }, 500)
  }
})

async function handle(req: Request): Promise<Response> {
  let body: any
  try { body = JSON.parse(await req.text()) } catch { return R({ error: 'bad json' }, 400) }

  const { action } = body

  // ── Cron / admin: run due schedules ──────────────────────────────────────
  if (action === 'run') {
    const cronKey = req.headers.get('x-cron-secret') ?? body.cron_secret ?? ''
    if (!CRON_SECRET || cronKey !== CRON_SECRET) return R({ error: 'Forbidden' }, 403)
    return await runDueSchedules()
  }

  // ── Member actions — require auth ─────────────────────────────────────────
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
  const { payment_type, amount, frequency, next_run_date, description } = body

  if (!payment_type) return R({ error: 'payment_type is required (savings, loan_repayment, shares)' }, 400)
  if (!amount || amount <= 0) return R({ error: 'amount must be > 0' }, 400)
  if (!frequency) return R({ error: 'frequency is required (daily, weekly, monthly)' }, 400)
  if (!next_run_date) return R({ error: 'next_run_date is required (YYYY-MM-DD)' }, 400)

  const validTypes = ['savings', 'loan_repayment', 'shares']
  if (!validTypes.includes(payment_type)) return R({ error: `payment_type must be one of: ${validTypes.join(', ')}` }, 400)

  const validFreqs = ['daily', 'weekly', 'monthly']
  if (!validFreqs.includes(frequency)) return R({ error: `frequency must be one of: ${validFreqs.join(', ')}` }, 400)

  const schedule = await dbInsert('scheduled_payments', {
    member_id: member.id,
    payment_type,
    amount,
    frequency,
    next_run_date,
    description: description ?? `${payment_type} - ${frequency}`,
    status: 'active',
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
  const { schedule_id, amount, frequency, next_run_date, description, status } = body
  if (!schedule_id) return R({ error: 'schedule_id is required' }, 400)

  // Verify ownership
  const rows = await dbSelect('scheduled_payments', `id=eq.${schedule_id}&member_id=eq.${member.id}&limit=1`)
  if (!rows[0]) return R({ error: 'Schedule not found' }, 404)

  const patch: any = { updated_at: new Date().toISOString() }
  if (amount !== undefined)       patch.amount        = amount
  if (frequency !== undefined)    patch.frequency     = frequency
  if (next_run_date !== undefined) patch.next_run_date = next_run_date
  if (description !== undefined)  patch.description   = description
  if (status !== undefined)       patch.status        = status

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
    status: 'cancelled',
    updated_at: new Date().toISOString(),
  })
  return R({ success: true })
}

// ── Run due schedules (cron) ──────────────────────────────────────────────────
async function runDueSchedules(): Promise<Response> {
  const today = new Date().toISOString().split('T')[0] // YYYY-MM-DD

  // Fetch all active schedules due today or overdue
  const due = await dbSelect(
    'scheduled_payments',
    `status=eq.active&next_run_date=lte.${today}&select=*`,
  )

  console.log(`[RATIBA] ${due.length} schedule(s) due on ${today}`)

  const results: any[] = []

  for (const schedule of due) {
    try {
      const result = await processSchedule(schedule)
      results.push({ schedule_id: schedule.id, ...result })
    } catch (e) {
      console.error(`[RATIBA] schedule ${schedule.id} error:`, (e as Error).message)
      results.push({ schedule_id: schedule.id, success: false, error: (e as Error).message })
    }
  }

  return R({ processed: results.length, results })
}

async function processSchedule(schedule: any): Promise<{ success: boolean; error?: string }> {
  // Fetch member + FOSA
  const members = await dbSelect('members', `id=eq.${schedule.member_id}&select=id,full_name,phone_number,status&limit=1`)
  const member = members[0]
  if (!member || member.status !== 'active') {
    await pauseSchedule(schedule.id, 'Member inactive or not found')
    return { success: false, error: 'Member inactive' }
  }

  const fosas = await dbSelect('fosa_accounts', `member_id=eq.${member.id}&select=id,balance&limit=1`)
  const fosa = fosas[0]
  if (!fosa) {
    await pauseSchedule(schedule.id, 'FOSA account not found')
    return { success: false, error: 'FOSA not found' }
  }

  const balance = parseFloat(fosa.balance)
  const amount  = parseFloat(schedule.amount)

  if (amount > balance) {
    console.warn(`[RATIBA] Insufficient balance for schedule ${schedule.id}: need ${amount}, have ${balance}`)
    // Advance next_run_date without deducting — will retry next cycle
    await advanceNextRun(schedule)
    return { success: false, error: `Insufficient FOSA balance (${balance.toFixed(2)})` }
  }

  // Normalise phone for M-Pesa B2C
  let phone = (member.phone_number ?? '').replace(/\D/g, '')
  if (phone.startsWith('0')) phone = `254${phone.slice(1)}`
  if (phone.startsWith('+')) phone = phone.slice(1)

  const ref = `RTB-${schedule.id.slice(0, 8)}-${Date.now()}`

  // Record pending transaction
  const tx = await dbInsert('transactions', {
    member_id:            member.id,
    account_type:         'fosa',
    transaction_type:     'scheduled_payment',
    amount,
    balance_before:       balance,
    reference:            ref,
    description:          schedule.description ?? `Scheduled ${schedule.payment_type}`,
    status:               'pending',
    scheduled_payment_id: schedule.id,
  })

  if (!tx?.id) {
    return { success: false, error: 'Failed to record transaction' }
  }

  // Deduct from FOSA immediately (same pattern as withdrawal / pay-bills)
  const newBalance = balance - amount
  await dbUpdate('fosa_accounts', `id=eq.${fosa.id}`, {
    balance:    newBalance,
    updated_at: new Date().toISOString(),
  })

  // Initiate IntaSend B2C payout to member's M-Pesa
  const intaRes = await fetch(`${IB}/send-money/initiate/`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Token ${IS}` },
    body:    JSON.stringify({
      currency:          'KES',
      provider:          'MPESA-B2C',
      requires_approval: 'NO',
      transactions: [{
        name:      member.full_name,
        account:   phone,
        amount:    amount.toString(),
        narrative: `Omwa Sacco - ${schedule.payment_type} - ${ref}`,
      }],
    }),
  })
  const intaData = await intaRes.json()
  console.log(`[RATIBA] IntaSend B2C ${intaRes.status}:`, JSON.stringify(intaData))

  if (!intaRes.ok) {
    // Rollback balance
    await dbUpdate('fosa_accounts', `id=eq.${fosa.id}`, {
      balance:    balance,
      updated_at: new Date().toISOString(),
    })
    await dbUpdate('transactions', `id=eq.${tx.id}`, { status: 'failed' })
    return { success: false, error: intaData?.errors?.[0]?.detail ?? 'IntaSend B2C failed' }
  }

  // Update transaction with IntaSend tracking ref
  await dbUpdate('transactions', `id=eq.${tx.id}`, {
    balance_after: newBalance,
    intasend_ref:  intaData.file_id ?? intaData.tracking_id ?? null,
    status:        'pending', // webhook will mark completed
  })

  // Advance next_run_date and update last_run_date
  await advanceNextRun(schedule)

  return { success: true }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function nextRunDate(currentDate: string, frequency: string): string {
  const d = new Date(currentDate)
  switch (frequency) {
    case 'daily':   d.setDate(d.getDate() + 1);   break
    case 'weekly':  d.setDate(d.getDate() + 7);   break
    case 'monthly': d.setMonth(d.getMonth() + 1); break
  }
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

async function pauseSchedule(scheduleId: string, reason: string): Promise<void> {
  console.warn(`[RATIBA] Pausing schedule ${scheduleId}: ${reason}`)
  await dbUpdate('scheduled_payments', `id=eq.${scheduleId}`, {
    status:     'paused',
    updated_at: new Date().toISOString(),
  })
}
