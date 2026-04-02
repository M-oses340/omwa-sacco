// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { jwtUserId, jsonResponse as json } from '../_shared/auth.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// ── Loan product rules ────────────────────────────────────────────────────────
interface Product {
  name: string; category: string; maxMonths: number
  multiplier: number; ratePa: number; monthlyRate?: number
  interestType: string; commissionPct: number; maxAmount?: number
  salaryRequired: boolean; noDividends: boolean
}

const PRODUCTS: Record<string, Product> = {
  normal:           { name: 'Normal Loan',           category: 'bosa',  maxMonths: 48,  multiplier: 5, ratePa: 12.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  jumbo:            { name: 'Jumbo Loan',             category: 'bosa',  maxMonths: 108, multiplier: 5, ratePa: 15.6, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  bima:             { name: 'Bima Loan',              category: 'bosa',  maxMonths: 12,  multiplier: 5, ratePa: 10.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  premier:          { name: 'Premier Loan',           category: 'bosa',  maxMonths: 96,  multiplier: 5, ratePa: 15.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  super:            { name: 'Super Loan',             category: 'bosa',  maxMonths: 72,  multiplier: 5, ratePa: 14.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  mega:             { name: 'Mega Loan',              category: 'bosa',  maxMonths: 84,  multiplier: 5, ratePa: 14.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  refinancing:      { name: 'Refinancing Loan',       category: 'bosa',  maxMonths: 60,  multiplier: 5, ratePa: 12.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  emergency:        { name: 'Emergency Loan',         category: 'bosa',  maxMonths: 24,  multiplier: 5, ratePa: 12.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  school_fees:      { name: 'School Fees Loan',       category: 'bosa',  maxMonths: 12,  multiplier: 5, ratePa: 12.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  asset_financing:  { name: 'Asset Financing Loan',   category: 'bosa',  maxMonths: 24,  multiplier: 5, ratePa: 12.0, interestType: 'reducing', commissionPct: 0, salaryRequired: false, noDividends: false },
  muslim:           { name: 'Muslim Loan',            category: 'bosa',  maxMonths: 60,  multiplier: 4, ratePa: 0,    interestType: 'none',     commissionPct: 7, salaryRequired: false, noDividends: true  },
  muslim_emergency: { name: 'Muslim Emergency Loan',  category: 'bosa',  maxMonths: 24,  multiplier: 4, ratePa: 0,    interestType: 'none',     commissionPct: 7, salaryRequired: false, noDividends: true  },
  msasa:            { name: 'M-Sasa',                 category: 'fosa',  maxMonths: 3,   multiplier: 0, ratePa: 0,    interestType: 'flat',     commissionPct: 0, monthlyRate: 2.0, salaryRequired: true,  noDividends: false },
  fosa_flex:        { name: 'FOSA Flex',              category: 'fosa',  maxMonths: 6,   multiplier: 0, ratePa: 0,    interestType: 'flat',     commissionPct: 0, monthlyRate: 3.0, salaryRequired: true,  noDividends: false },
  fosa_golden:      { name: 'FOSA Golden',            category: 'fosa',  maxMonths: 9,   multiplier: 0, ratePa: 0,    interestType: 'reducing', commissionPct: 0, monthlyRate: 3.5, salaryRequired: true,  noDividends: false },
  fosa_ultra:       { name: 'FOSA Ultra',             category: 'fosa',  maxMonths: 12,  multiplier: 0, ratePa: 0,    interestType: 'flat',     commissionPct: 0, monthlyRate: 4.0, salaryRequired: true,  noDividends: false },
  qcash:            { name: 'Q-Cash',                 category: 'special', maxMonths: 2, multiplier: 0, ratePa: 0,    interestType: 'disbursement', commissionPct: 5, maxAmount: 40000, salaryRequired: false, noDividends: false },
  dividend_advance: { name: 'Dividend Advance',       category: 'special', maxMonths: 1, multiplier: 0, ratePa: 0,    interestType: 'disbursement', commissionPct: 10, salaryRequired: false, noDividends: false },
}

function calcRepayment(p: Product, principal: number, months: number) {
  let monthly = 0, total = 0, commission = 0
  if (p.interestType === 'reducing') {
    const mr = (p.monthlyRate ?? p.ratePa / 12) / 100
    monthly = (principal * mr * Math.pow(1 + mr, months)) / (Math.pow(1 + mr, months) - 1)
    total = monthly * months
  } else if (p.interestType === 'flat') {
    const mr = (p.monthlyRate ?? 0) / 100
    total = principal + principal * mr * months
    monthly = total / months
  } else if (p.interestType === 'disbursement') {
    commission = principal * p.commissionPct / 100
    total = principal + commission
    monthly = total / months
  } else {
    commission = principal * p.commissionPct / 100
    monthly = principal / months
    total = principal
  }
  return { monthly: +monthly.toFixed(2), total: +total.toFixed(2), commission: +commission.toFixed(2) }
}

async function nextLoanNumber() {
  const year = new Date().getFullYear()
  const { count } = await supabase.from('loans').select('*', { count: 'exact', head: true }).gte('created_at', `${year}-01-01`)
  return `LN-${year}-${String((count ?? 0) + 1).padStart(4, '0')}`
}

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  const userId = jwtUserId(req.headers.get('Authorization'))
  if (!userId) return json({ error: 'Unauthorized' }, 401)

  try {
    const { data: member } = await supabase
      .from('members').select('id, status, role').eq('user_id', userId).single()
    if (!member) return json({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return json({ error: 'Account not active' }, 403)

    const body = await req.json()
    const isAdmin = ['admin', 'treasurer', 'chairman'].includes(member.role)

    switch (body.action) {
      case 'apply':       return await applyLoan(member.id, body)
      case 'eligibility': return await getEligibility(member.id)
      case 'schedule':    return await getSchedule(member.id, body)
      case 'repay':       return await repayLoan(member.id, body)
      case 'approve':     return isAdmin ? await approveLoan(body) : json({ error: 'Forbidden' }, 403)
      case 'disburse':    return isAdmin ? await disburseLoan(body) : json({ error: 'Forbidden' }, 403)
      default:            return json({ error: 'Invalid action' }, 400)
    }
  } catch (e) {
    console.error('[LOANS]', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

// ── Eligibility ───────────────────────────────────────────────────────────────
async function getEligibility(memberId: string) {
  const [bosaRes, fosaRes, activeLoanRes] = await Promise.all([
    supabase.from('bosa_accounts').select('savings_balance').eq('member_id', memberId).maybeSingle(),
    supabase.from('fosa_accounts').select('salary_amount').eq('member_id', memberId).maybeSingle(),
    supabase.from('loans').select('id, loan_number, loan_type, status, outstanding_balance')
      .eq('member_id', memberId).in('status', ['pending', 'approved', 'disbursed']).maybeSingle(),
  ])
  const savings = parseFloat(bosaRes.data?.savings_balance ?? '0')
  return json({
    bosa_savings: savings,
    has_salary_via_fosa: (fosaRes.data?.salary_amount ?? 0) > 0,
    active_loan: activeLoanRes.data ?? null,
    limits: { bosa_5x: +(savings * 5).toFixed(2), bosa_4x: +(savings * 4).toFixed(2) },
    can_apply: !activeLoanRes.data,
  })
}

// ── Apply ─────────────────────────────────────────────────────────────────────
async function applyLoan(memberId: string, body: any) {
  const { loan_type, principal, duration_months, purpose } = body
  const p = PRODUCTS[loan_type]
  if (!p) return json({ error: 'Invalid loan type' }, 400)
  if (!principal || principal < 1000) return json({ error: 'Minimum loan is KES 1,000' }, 400)
  if (!duration_months || duration_months < 1 || duration_months > p.maxMonths)
    return json({ error: `${p.name} max duration is ${p.maxMonths} months` }, 400)
  if (p.maxAmount && principal > p.maxAmount)
    return json({ error: `${p.name} maximum is KES ${p.maxAmount.toLocaleString()}` }, 400)

  const { data: fosa } = await supabase.from('fosa_accounts').select('id, salary_amount').eq('member_id', memberId).single()
  if (!fosa) return json({ error: 'FOSA account not found' }, 404)
  if (p.salaryRequired && !(fosa.salary_amount > 0))
    return json({ error: `${p.name} requires salary processed through FOSA` }, 400)

  if (p.multiplier > 0) {
    const { data: bosa } = await supabase.from('bosa_accounts').select('savings_balance').eq('member_id', memberId).single()
    if (!bosa) return json({ error: 'BOSA account not found' }, 404)
    const limit = bosa.savings_balance * p.multiplier
    if (limit <= 0) return json({ error: 'No BOSA deposits to qualify' }, 400)
    if (principal > limit) return json({ error: `Exceeds limit of KES ${limit.toFixed(2)} (${p.multiplier}× deposits)` }, 400)
  }

  if (loan_type === 'dividend_advance') {
    const lastYear = new Date().getFullYear() - 1
    const { data: divs } = await supabase.from('transactions').select('amount')
      .eq('member_id', memberId).eq('transaction_type', 'dividend')
      .gte('created_at', `${lastYear}-01-01`).lte('created_at', `${lastYear}-12-31`)
    const total = (divs ?? []).reduce((s: number, t: any) => s + parseFloat(t.amount), 0)
    const max = total * 0.5
    if (max <= 0) return json({ error: 'No dividends received last year' }, 400)
    if (principal > max) return json({ error: `Capped at 50% of ${lastYear} dividends: KES ${max.toFixed(2)}` }, 400)
  }

  const { data: existing } = await supabase.from('loans').select('loan_number')
    .eq('member_id', memberId).in('status', ['pending', 'approved', 'disbursed']).maybeSingle()
  if (existing) return json({ error: `Active loan exists (${existing.loan_number})` }, 400)

  const rep = calcRepayment(p, principal, duration_months)
  const loanNumber = await nextLoanNumber()

  const { data: loan, error } = await supabase.from('loans').insert({
    member_id: memberId, loan_number: loanNumber, loan_type,
    principal, commission_amount: rep.commission, interest_rate: p.ratePa,
    duration_months, monthly_repayment: rep.monthly, total_repayable: rep.total,
    outstanding_balance: rep.total, purpose: purpose ?? '', status: 'pending',
    disbursed_to_fosa_id: fosa.id,
  }).select().single()

  if (error) return json({ error: 'Failed to submit application' }, 500)

  // Build amortization schedule
  const schedule = buildSchedule(p, principal, duration_months, rep.monthly)

  return json({ success: true, loan, summary: { ...rep, no_dividends: p.noDividends }, schedule })
}

// ── Schedule ──────────────────────────────────────────────────────────────────
async function getSchedule(memberId: string, body: any) {
  const { loan_id } = body
  const { data: loan } = await supabase.from('loans').select('*')
    .eq('id', loan_id).eq('member_id', memberId).single()
  if (!loan) return json({ error: 'Loan not found' }, 404)
  const p = PRODUCTS[loan.loan_type]
  if (!p) return json({ error: 'Unknown loan type' }, 400)
  return json({ schedule: buildSchedule(p, parseFloat(loan.principal), loan.duration_months, parseFloat(loan.monthly_repayment)) })
}

function buildSchedule(p: Product, principal: number, months: number, monthly: number) {
  const schedule = []
  if (p.interestType === 'reducing') {
    const mr = (p.monthlyRate ?? p.ratePa / 12) / 100
    let balance = principal
    for (let m = 1; m <= months; m++) {
      const interest = +(balance * mr).toFixed(2)
      const princ = +(monthly - interest).toFixed(2)
      balance = +Math.max(0, balance - princ).toFixed(2)
      schedule.push({ month: m, payment: monthly, principal: princ, interest, balance })
    }
  } else {
    const perMonth = +(principal / months).toFixed(2)
    let balance = principal
    for (let m = 1; m <= months; m++) {
      balance = +Math.max(0, balance - perMonth).toFixed(2)
      schedule.push({ month: m, payment: monthly, principal: perMonth, interest: 0, balance })
    }
  }
  return schedule
}

// ── Repay ─────────────────────────────────────────────────────────────────────
async function repayLoan(memberId: string, body: any) {
  const { loan_id, amount } = body
  if (!amount || amount <= 0) return json({ error: 'Invalid amount' }, 400)

  const { data: loan } = await supabase.from('loans').select('*')
    .eq('id', loan_id).eq('member_id', memberId).eq('status', 'disbursed').single()
  if (!loan) return json({ error: 'Active disbursed loan not found' }, 404)

  const { data: fosa } = await supabase.from('fosa_accounts').select('id, balance').eq('member_id', memberId).single()
  if (!fosa) return json({ error: 'FOSA account not found' }, 404)

  const fosaBalance = parseFloat(fosa.balance)
  if (amount > fosaBalance) return json({ error: `Insufficient FOSA balance. Available: KES ${fosaBalance.toFixed(2)}` }, 400)

  const outstanding = parseFloat(loan.outstanding_balance)
  const repayAmount = Math.min(amount, outstanding)
  const newOutstanding = +(outstanding - repayAmount).toFixed(2)
  const newRepaid = +(parseFloat(loan.amount_repaid) + repayAmount).toFixed(2)
  const newFosaBalance = +(fosaBalance - repayAmount).toFixed(2)
  const isFullyRepaid = newOutstanding <= 0

  await supabase.from('loans').update({
    amount_repaid: newRepaid, outstanding_balance: newOutstanding,
    status: isFullyRepaid ? 'repaid' : 'disbursed',
    updated_at: new Date().toISOString(),
  }).eq('id', loan_id)

  await supabase.from('fosa_accounts').update({ balance: newFosaBalance }).eq('id', fosa.id)

  await supabase.from('transactions').insert({
    member_id: memberId, account_type: 'bosa', transaction_type: 'loan_repayment',
    amount: repayAmount, balance_before: fosaBalance, balance_after: newFosaBalance,
    reference: `REP-${Date.now()}`,
    description: `Loan repayment for ${loan.loan_number}`, status: 'completed',
  })

  return json({ success: true, amount_paid: repayAmount, balance_after: newOutstanding, fully_repaid: isFullyRepaid })
}

// ── Approve (admin) ───────────────────────────────────────────────────────────
async function approveLoan(body: any) {
  const { loan_id } = body
  const { error } = await supabase.from('loans').update({
    status: 'approved', approved_at: new Date().toISOString(),
  }).eq('id', loan_id).eq('status', 'pending')
  if (error) return json({ error: error.message }, 500)
  return json({ success: true })
}

// ── Disburse (admin) ──────────────────────────────────────────────────────────
async function disburseLoan(body: any) {
  const { loan_id } = body

  const { data: loan } = await supabase.from('loans').select('*').eq('id', loan_id).eq('status', 'approved').single()
  if (!loan) return json({ error: 'Approved loan not found' }, 404)

  const { data: fosa } = await supabase.from('fosa_accounts').select('id, balance').eq('id', loan.disbursed_to_fosa_id).single()
  if (!fosa) return json({ error: 'FOSA account not found' }, 404)

  const principal = parseFloat(loan.principal)
  const newBalance = parseFloat(fosa.balance) + principal
  const dueDate = new Date()
  dueDate.setMonth(dueDate.getMonth() + loan.duration_months)

  await supabase.from('fosa_accounts').update({ balance: newBalance }).eq('id', fosa.id)
  await supabase.from('loans').update({
    status: 'disbursed', disbursed_at: new Date().toISOString(),
    due_date: dueDate.toISOString().split('T')[0],
  }).eq('id', loan_id)

  await supabase.from('transactions').insert({
    member_id: loan.member_id, account_type: 'fosa', transaction_type: 'loan_disbursement',
    amount: principal, balance_before: parseFloat(fosa.balance), balance_after: newBalance,
    reference: `DIS-${Date.now()}`, description: `Loan disbursement for ${loan.loan_number}`, status: 'completed',
  })

  return json({ success: true })
}
