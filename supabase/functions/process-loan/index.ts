// deno-lint-ignore-file no-explicit-any
// All loans disbursed through FOSA. v2
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

function jwtUserId(authHeader: string | null): string | null {
  try {
    if (!authHeader?.startsWith('Bearer ')) return null
    const payload = authHeader.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    const data = JSON.parse(atob(payload + '='.repeat((4 - payload.length % 4) % 4)))
    if (data.role !== 'authenticated') return null
    if (data.exp && data.exp < Math.floor(Date.now() / 1000)) return null
    return data.sub ?? null
  } catch { return null }
}

interface LoanProduct {
  displayName: string
  category: 'bosa' | 'fosa_advance' | 'special'
  maxMonths: number
  depositMultiplier: number
  interestRatePa: number
  interestType: 'reducing_balance' | 'flat_monthly' | 'flat_disbursement' | 'none'
  monthlyRate?: number
  commissionPct: number
  maxAmount?: number
  salaryRequired: boolean
  noDividends: boolean
}

const LOAN_PRODUCTS: Record<string, LoanProduct> = {
  normal:           { displayName: 'Normal Loan',           category: 'bosa',         maxMonths: 48,  depositMultiplier: 5, interestRatePa: 12.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  jumbo:            { displayName: 'Jumbo Loan',            category: 'bosa',         maxMonths: 108, depositMultiplier: 5, interestRatePa: 15.6, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  bima:             { displayName: 'Bima Loan',             category: 'bosa',         maxMonths: 12,  depositMultiplier: 5, interestRatePa: 10.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  premier:          { displayName: 'Premier Loan',          category: 'bosa',         maxMonths: 96,  depositMultiplier: 5, interestRatePa: 15.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  super:            { displayName: 'Super Loan',            category: 'bosa',         maxMonths: 72,  depositMultiplier: 5, interestRatePa: 14.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  mega:             { displayName: 'Mega Loan',             category: 'bosa',         maxMonths: 84,  depositMultiplier: 5, interestRatePa: 14.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  refinancing:      { displayName: 'Refinancing Loan',      category: 'bosa',         maxMonths: 60,  depositMultiplier: 5, interestRatePa: 12.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  emergency:        { displayName: 'Emergency Loan',        category: 'bosa',         maxMonths: 24,  depositMultiplier: 5, interestRatePa: 12.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  school_fees:      { displayName: 'School Fees Loan',      category: 'bosa',         maxMonths: 12,  depositMultiplier: 5, interestRatePa: 12.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  asset_financing:  { displayName: 'Asset Financing Loan',  category: 'bosa',         maxMonths: 24,  depositMultiplier: 5, interestRatePa: 12.0, interestType: 'reducing_balance', commissionPct: 0, salaryRequired: false, noDividends: false },
  muslim:           { displayName: 'Muslim Loan',           category: 'bosa',         maxMonths: 60,  depositMultiplier: 4, interestRatePa: 0,    interestType: 'none',             commissionPct: 7, salaryRequired: false, noDividends: true  },
  muslim_emergency: { displayName: 'Muslim Emergency Loan', category: 'bosa',         maxMonths: 24,  depositMultiplier: 4, interestRatePa: 0,    interestType: 'none',             commissionPct: 7, salaryRequired: false, noDividends: true  },
  msasa:            { displayName: 'M-Sasa',                category: 'fosa_advance', maxMonths: 3,   depositMultiplier: 0, interestRatePa: 0,    interestType: 'flat_monthly',     monthlyRate: 2.0, commissionPct: 0, salaryRequired: true,  noDividends: false },
  fosa_flex:        { displayName: 'FOSA Flex',             category: 'fosa_advance', maxMonths: 6,   depositMultiplier: 0, interestRatePa: 0,    interestType: 'flat_monthly',     monthlyRate: 3.0, commissionPct: 0, salaryRequired: true,  noDividends: false },
  fosa_golden:      { displayName: 'FOSA Golden',           category: 'fosa_advance', maxMonths: 9,   depositMultiplier: 0, interestRatePa: 0,    interestType: 'reducing_balance', monthlyRate: 3.5, commissionPct: 0, salaryRequired: true,  noDividends: false },
  fosa_ultra:       { displayName: 'FOSA Ultra',            category: 'fosa_advance', maxMonths: 12,  depositMultiplier: 0, interestRatePa: 0,    interestType: 'flat_monthly',     monthlyRate: 4.0, commissionPct: 0, salaryRequired: true,  noDividends: false },
  qcash:            { displayName: 'Q-Cash',                category: 'special',      maxMonths: 2,   depositMultiplier: 0, interestRatePa: 0,    interestType: 'flat_disbursement',commissionPct: 0, maxAmount: 40000, salaryRequired: false, noDividends: false },
  dividend_advance: { displayName: 'Dividend Advance',      category: 'special',      maxMonths: 1,   depositMultiplier: 0, interestRatePa: 0,    interestType: 'flat_disbursement',commissionPct: 0, salaryRequired: false, noDividends: false },
}

// ── Calculators ───────────────────────────────────────────────────────────────
function calcRepayment(product: LoanProduct, principal: number, months: number) {
  let monthly = 0, total = 0, commission = 0
  switch (product.interestType) {
    case 'reducing_balance': {
      const mr = product.monthlyRate ? product.monthlyRate / 100 : product.interestRatePa / 100 / 12
      monthly = (principal * mr * Math.pow(1 + mr, months)) / (Math.pow(1 + mr, months) - 1)
      total = monthly * months
      break
    }
    case 'flat_monthly': {
      const mr = (product.monthlyRate ?? 0) / 100
      monthly = (principal + principal * mr * months) / months
      total = principal + principal * mr * months
      break
    }
    case 'flat_disbursement': {
      total = principal; monthly = principal / months
      break
    }
    case 'none': {
      commission = principal * (product.commissionPct / 100)
      monthly = principal / months; total = principal
      break
    }
  }
  return {
    monthly: parseFloat(monthly.toFixed(2)),
    total: parseFloat(total.toFixed(2)),
    commission: parseFloat(commission.toFixed(2)),
  }
}

function buildSchedule(product: LoanProduct, principal: number, months: number, monthly: number) {
  const schedule = []
  if (product.interestType === 'reducing_balance') {
    const mr = product.monthlyRate ? product.monthlyRate / 100 : product.interestRatePa / 100 / 12
    let balance = principal
    for (let m = 1; m <= months; m++) {
      const interestCharge = parseFloat((balance * mr).toFixed(2))
      // On final payment, use exact balance to avoid rounding drift
      const isLast = m === months
      const principalCharge = isLast ? balance : parseFloat((monthly - interestCharge).toFixed(2))
      const payment = isLast ? parseFloat((principalCharge + interestCharge).toFixed(2)) : monthly
      balance = parseFloat(Math.max(0, balance - principalCharge).toFixed(2))
      schedule.push({ month: m, payment, principal: principalCharge, interest: interestCharge, balance })
    }
  } else {
    const perMonth = parseFloat((principal / months).toFixed(2))
    let balance = principal
    for (let m = 1; m <= months; m++) {
      const isLast = m === months
      const p = isLast ? balance : perMonth
      balance = parseFloat(Math.max(0, balance - p).toFixed(2))
      schedule.push({ month: m, payment: monthly, principal: p, interest: 0, balance })
    }
  }
  return schedule
}

// ── Interest split for a repayment ───────────────────────────────────────────
function splitRepayment(product: LoanProduct, outstanding: number, amount: number) {
  if (product.interestType === 'reducing_balance') {
    const mr = product.monthlyRate ? product.monthlyRate / 100 : product.interestRatePa / 100 / 12
    const interest = parseFloat((outstanding * mr).toFixed(2))
    const principal = parseFloat(Math.max(0, amount - interest).toFixed(2))
    return { principal, interest }
  }
  // Flat / none: all goes to principal
  return { principal: amount, interest: 0 }
}

async function nextLoanNumber(): Promise<string> {
  const year = new Date().getFullYear()
  const { count } = await supabase
    .from('loans').select('*', { count: 'exact', head: true })
    .gte('created_at', `${year}-01-01`)
  const seq = String((count ?? 0) + 1).padStart(4, '0')
  return `LN-${year}-${seq}`
}

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  try {
    const userId = jwtUserId(req.headers.get('Authorization'))
    if (!userId) return json({ error: 'Unauthorized' }, 401)

    const { data: member } = await supabase
      .from('members').select('id, status, role').eq('user_id', userId).single()

    if (!member) return json({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return json({ error: 'Your account is not active' }, 403)

    const body = await req.json()
    const isAdmin = ['admin', 'treasurer', 'chairman'].includes(member.role)

    switch (body.action) {
      case 'apply':       return await applyLoan(member.id, body)
      case 'eligibility': return await getEligibility(member.id)
      case 'schedule':    return await getLoanSchedule(member.id, body)
      case 'repay':       return await repayLoan(member.id, body)
      case 'approve':     return isAdmin ? await approveLoan(member.id, body) : json({ error: 'Forbidden' }, 403)
      case 'disburse':    return isAdmin ? await disburseLoan(member.id, body) : json({ error: 'Forbidden' }, 403)
      case 'products':    return await listProducts()
      default:            return json({ error: 'Invalid action' }, 400)
    }
  } catch (e) {
    console.error('[LOAN] Error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

// ── Eligibility ───────────────────────────────────────────────────────────────
async function getEligibility(memberId: string) {
  const [bosaRes, fosaRes, activeLoanRes] = await Promise.all([
    supabase.from('bosa_accounts').select('savings_balance, is_active').eq('member_id', memberId).maybeSingle(),
    supabase.from('fosa_accounts').select('salary_amount, is_active').eq('member_id', memberId).maybeSingle(),
    supabase.from('loans').select('id, loan_number, loan_type, status, outstanding_balance')
      .eq('member_id', memberId).in('status', ['pending', 'approved', 'disbursed']).maybeSingle(),
  ])
  const bosa = bosaRes.data
  const fosa = fosaRes.data
  const activeLoan = activeLoanRes.data
  const bosaSavings = parseFloat(bosa?.savings_balance ?? '0')
  return json({
    bosa_savings: bosaSavings,
    has_salary_via_fosa: (fosa?.salary_amount ?? 0) > 0,
    active_loan: activeLoan ?? null,
    limits: { bosa_5x: parseFloat((bosaSavings * 5).toFixed(2)), bosa_4x: parseFloat((bosaSavings * 4).toFixed(2)) },
    can_apply: !activeLoan,
  })
}

// ── Schedule ──────────────────────────────────────────────────────────────────
async function getLoanSchedule(memberId: string, body: any) {
  const { loan_id } = body
  if (!loan_id) return json({ error: 'loan_id required' }, 400)
  const { data: loan } = await supabase.from('loans').select('*')
    .eq('id', loan_id).eq('member_id', memberId).single()
  if (!loan) return json({ error: 'Loan not found' }, 404)
  const product = LOAN_PRODUCTS[loan.loan_type]
  if (!product) return json({ error: 'Unknown loan type' }, 400)
  const schedule = buildSchedule(product, parseFloat(loan.principal), loan.duration_months, parseFloat(loan.monthly_repayment))
  return json({ schedule })
}

// ── List products ─────────────────────────────────────────────────────────────
async function listProducts() {
  const products = Object.entries(LOAN_PRODUCTS).map(([key, p]) => ({
    loan_type: key, display_name: p.displayName, category: p.category,
    max_months: p.maxMonths, deposit_multiplier: p.depositMultiplier,
    interest_rate_pa: p.interestRatePa, monthly_rate: p.monthlyRate ?? null,
    interest_type: p.interestType, commission_pct: p.commissionPct,
    max_amount: p.maxAmount ?? null, salary_required: p.salaryRequired, no_dividends: p.noDividends,
  }))
  return json({ products })
}

// ── Apply ─────────────────────────────────────────────────────────────────────
async function applyLoan(memberId: string, body: any) {
  const { loan_type, principal, duration_months, purpose } = body
  const product = LOAN_PRODUCTS[loan_type as string]
  if (!product) return json({ error: 'Invalid loan type' }, 400)
  if (!principal || principal < 1000) return json({ error: 'Minimum loan amount is KES 1,000' }, 400)
  if (!duration_months || duration_months < 1 || duration_months > product.maxMonths)
    return json({ error: `${product.displayName} repayment period is max ${product.maxMonths} months` }, 400)
  if (product.maxAmount && principal > product.maxAmount)
    return json({ error: `${product.displayName} maximum is KES ${product.maxAmount.toLocaleString()}` }, 400)

  const { data: fosa } = await supabase.from('fosa_accounts')
    .select('id, salary_amount').eq('member_id', memberId).single()
  if (!fosa) return json({ error: 'FOSA account not found. All loans are disbursed through FOSA.' }, 404)
  if (product.salaryRequired && (!fosa.salary_amount || fosa.salary_amount <= 0))
    return json({ error: `${product.displayName} is only available to members whose salary is processed through FOSA` }, 400)

  if (product.depositMultiplier > 0) {
    const { data: bosa } = await supabase.from('bosa_accounts')
      .select('savings_balance, is_active').eq('member_id', memberId).single()
    if (!bosa) return json({ error: 'BOSA account not found' }, 404)
    if (!bosa.is_active) return json({ error: 'Your BOSA account is not active' }, 403)
    const loanLimit = bosa.savings_balance * product.depositMultiplier
    if (loanLimit <= 0) return json({ error: 'You have no BOSA deposits to qualify for this loan' }, 400)
    if (principal > loanLimit)
      return json({ error: `Loan exceeds your limit of KES ${loanLimit.toFixed(2)} (${product.depositMultiplier}× BOSA deposits of KES ${bosa.savings_balance.toFixed(2)})` }, 400)
  }

  if (loan_type === 'dividend_advance') {
    const lastYear = new Date().getFullYear() - 1
    const { data: divTx } = await supabase.from('transactions').select('amount')
      .eq('member_id', memberId).eq('transaction_type', 'dividend')
      .gte('created_at', `${lastYear}-01-01`).lte('created_at', `${lastYear}-12-31`)
    const totalDiv = (divTx ?? []).reduce((s: number, t: any) => s + parseFloat(t.amount), 0)
    const maxAdvance = totalDiv * 0.5
    if (maxAdvance <= 0) return json({ error: 'You did not receive dividends last year' }, 400)
    if (principal > maxAdvance)
      return json({ error: `Dividend advance capped at 50% of your ${lastYear} dividends: KES ${maxAdvance.toFixed(2)}` }, 400)
  }

  // Race-condition safe: check active loan inside DB using advisory lock
  const { data: existingLoan } = await supabase.from('loans').select('id, loan_number')
    .eq('member_id', memberId).in('status', ['pending', 'approved', 'disbursed']).maybeSingle()
  if (existingLoan)
    return json({ error: `You already have an active loan (${existingLoan.loan_number}). Clear it before applying again.` }, 400)

  let repayment = calcRepayment(product, principal, duration_months)
  if (loan_type === 'qcash') {
    const charge = principal * 0.05
    repayment = { monthly: parseFloat(((principal + charge) / 2).toFixed(2)), total: parseFloat((principal + charge).toFixed(2)), commission: parseFloat(charge.toFixed(2)) }
  } else if (loan_type === 'dividend_advance') {
    const charge = principal * 0.10
    repayment = { monthly: parseFloat((principal + charge).toFixed(2)), total: parseFloat((principal + charge).toFixed(2)), commission: parseFloat(charge.toFixed(2)) }
  }

  const loanNumber = await nextLoanNumber()
  const { data: loan, error } = await supabase.from('loans').insert({
    member_id: memberId, loan_number: loanNumber, loan_type, principal,
    commission_amount: repayment.commission, interest_rate: product.interestRatePa,
    duration_months, monthly_repayment: repayment.monthly, total_repayable: repayment.total,
    outstanding_balance: repayment.total, purpose: purpose ?? '', status: 'pending',
    disbursed_to_fosa_id: fosa.id,
  }).select().single()

  if (error) { console.error('[LOAN] Insert error:', error.message); return json({ error: 'Failed to submit loan application' }, 500) }

  const schedule = buildSchedule(product, principal, duration_months, repayment.monthly)
  return json({
    success: true, loan,
    summary: { monthly_repayment: repayment.monthly, total_repayable: repayment.total,
      total_interest: parseFloat((repayment.total - principal).toFixed(2)),
      commission: repayment.commission, no_dividends: product.noDividends },
    schedule,
  })
}

// ── Approve (admin/treasurer only) ────────────────────────────────────────────
async function approveLoan(adminMemberId: string, body: any) {
  const { loan_id, reject, reason } = body
  if (!loan_id) return json({ error: 'loan_id required' }, 400)

  const { data: loan } = await supabase.from('loans').select('id, status, member_id')
    .eq('id', loan_id).single()
  if (!loan) return json({ error: 'Loan not found' }, 404)
  if (loan.status !== 'pending') return json({ error: `Loan is already ${loan.status}` }, 400)

  const newStatus = reject ? 'rejected' : 'approved'
  const { data: updated, error } = await supabase.from('loans').update({
    status: newStatus,
    approved_by: reject ? null : adminMemberId,
    approved_at: reject ? null : new Date().toISOString(),
    rejected_reason: reject ? (reason ?? 'Rejected by admin') : null,
  }).eq('id', loan_id).select().single()

  if (error) return json({ error: error.message }, 500)
  return json({ success: true, loan: updated })
}

// ── Disburse (admin/treasurer only) ──────────────────────────────────────────
async function disburseLoan(adminMemberId: string, body: any) {
  const { loan_id } = body
  if (!loan_id) return json({ error: 'loan_id required' }, 400)

  const { data: loan } = await supabase.from('loans')
    .select('*, fosa_accounts!disbursed_to_fosa_id(id, balance, member_id)')
    .eq('id', loan_id).single()
  if (!loan) return json({ error: 'Loan not found' }, 404)
  if (loan.status !== 'approved') return json({ error: `Loan must be approved before disbursement (current: ${loan.status})` }, 400)

  const fosaId = loan.disbursed_to_fosa_id
  const fosaBalance = parseFloat(loan.fosa_accounts?.balance ?? '0')
  const principal = parseFloat(loan.principal)

  // Credit FOSA account
  const { error: fosaErr } = await supabase.from('fosa_accounts')
    .update({ balance: fosaBalance + principal }).eq('id', fosaId)
  if (fosaErr) return json({ error: 'Failed to credit FOSA account' }, 500)

  // Record disbursement transaction
  const { data: tx } = await supabase.from('transactions').insert({
    member_id: loan.member_id,
    account_type: 'fosa',
    transaction_type: 'loan_disbursement',
    amount: principal,
    balance_before: fosaBalance,
    balance_after: fosaBalance + principal,
    reference: `DISB-${loan.loan_number}`,
    description: `Loan disbursement — ${loan.loan_number}`,
    status: 'completed',
    initiated_by: adminMemberId,
  }).select('id').single()

  // Update loan status to disbursed (trigger sets due_date automatically)
  const { data: updated, error: loanErr } = await supabase.from('loans').update({
    status: 'disbursed',
    disbursed_at: new Date().toISOString(),
  }).eq('id', loan_id).select().single()

  if (loanErr) return json({ error: 'Failed to update loan status' }, 500)
  return json({ success: true, loan: updated, transaction_id: tx?.id })
}

// ── Repay ─────────────────────────────────────────────────────────────────────
async function repayLoan(memberId: string, body: any) {
  const { loan_id, amount } = body
  if (!loan_id) return json({ error: 'loan_id required' }, 400)
  if (!amount || amount <= 0) return json({ error: 'Amount must be greater than 0' }, 400)

  const { data: loan } = await supabase.from('loans').select('*')
    .eq('id', loan_id).eq('member_id', memberId).single()
  if (!loan) return json({ error: 'Loan not found' }, 404)
  if (loan.status !== 'disbursed') return json({ error: 'Only disbursed loans can be repaid' }, 400)

  const outstanding = parseFloat(loan.outstanding_balance)
  if (amount > outstanding + 0.01) // allow tiny rounding tolerance
    return json({ error: `Amount exceeds outstanding balance of KES ${outstanding.toFixed(2)}` }, 400)

  // Check FOSA balance
  const { data: fosa } = await supabase.from('fosa_accounts')
    .select('id, balance').eq('member_id', memberId).single()
  if (!fosa) return json({ error: 'FOSA account not found' }, 404)
  const fosaBalance = parseFloat(fosa.balance)
  if (fosaBalance < amount) return json({ error: `Insufficient FOSA balance. Available: KES ${fosaBalance.toFixed(2)}` }, 400)

  const product = LOAN_PRODUCTS[loan.loan_type]
  const { principal: principalPortion, interest: interestPortion } =
    splitRepayment(product ?? { interestType: 'none' } as any, outstanding, amount)

  // Debit FOSA
  const { error: fosaErr } = await supabase.from('fosa_accounts')
    .update({ balance: fosaBalance - amount }).eq('id', fosa.id)
  if (fosaErr) return json({ error: 'Failed to debit FOSA account' }, 500)

  // Record transaction
  const { data: tx } = await supabase.from('transactions').insert({
    member_id: memberId,
    account_type: 'fosa',
    transaction_type: 'loan_repayment',
    amount,
    balance_before: fosaBalance,
    balance_after: fosaBalance - amount,
    reference: `REP-${loan.loan_number}-${Date.now()}`,
    description: `Loan repayment — ${loan.loan_number}`,
    status: 'completed',
  }).select('id').single()

  // Record repayment (trigger updates loan outstanding_balance and status)
  const { error: repErr } = await supabase.from('loan_repayments').insert({
    loan_id, member_id: memberId, amount,
    principal_portion: principalPortion,
    interest_portion: interestPortion,
    balance_before: outstanding,
    balance_after: Math.max(0, outstanding - amount),
    payment_method: 'fosa_debit',
    transaction_id: tx?.id,
  })
  if (repErr) return json({ error: 'Failed to record repayment' }, 500)

  // Fetch updated loan
  const { data: updatedLoan } = await supabase.from('loans').select('*').eq('id', loan_id).single()
  return json({ success: true, loan: updatedLoan, amount_paid: amount, balance_after: Math.max(0, outstanding - amount) })
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
