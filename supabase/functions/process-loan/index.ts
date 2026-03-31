// deno-lint-ignore-file no-explicit-any
// Business rules encoded here mirror the loan_products table.
// All loans disbursed through FOSA.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// ── Loan product definitions ──────────────────────────────────────────────────
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

// ── Repayment calculator ──────────────────────────────────────────────────────
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
      const interest = principal * mr * months
      monthly = (principal + interest) / months
      total = principal + interest
      break
    }
    case 'flat_disbursement': {
      total = principal
      monthly = principal / months
      break
    }
    case 'none': {
      commission = principal * (product.commissionPct / 100)
      monthly = principal / months
      total = principal
      break
    }
  }

  return {
    monthly: parseFloat(monthly.toFixed(2)),
    total: parseFloat(total.toFixed(2)),
    commission: parseFloat(commission.toFixed(2)),
  }
}

// ── Amortization schedule (reducing balance only, others are flat) ────────────
function buildSchedule(
  product: LoanProduct,
  principal: number,
  months: number,
  monthly: number
): Array<{ month: number; payment: number; principal: number; interest: number; balance: number }> {
  const schedule = []

  if (product.interestType === 'reducing_balance') {
    const mr = product.monthlyRate ? product.monthlyRate / 100 : product.interestRatePa / 100 / 12
    let balance = principal
    for (let m = 1; m <= months; m++) {
      const interestCharge = parseFloat((balance * mr).toFixed(2))
      const principalCharge = parseFloat((monthly - interestCharge).toFixed(2))
      balance = parseFloat(Math.max(0, balance - principalCharge).toFixed(2))
      schedule.push({ month: m, payment: monthly, principal: principalCharge, interest: interestCharge, balance })
    }
  } else {
    // Flat: equal payments, no interest breakdown needed
    const perMonth = parseFloat((principal / months).toFixed(2))
    let balance = principal
    for (let m = 1; m <= months; m++) {
      balance = parseFloat(Math.max(0, balance - perMonth).toFixed(2))
      schedule.push({ month: m, payment: monthly, principal: perMonth, interest: 0, balance })
    }
  }

  return schedule
}

// ── Sequential loan number ────────────────────────────────────────────────────
async function nextLoanNumber(): Promise<string> {
  const year = new Date().getFullYear()
  const { count } = await supabase
    .from('loans')
    .select('*', { count: 'exact', head: true })
    .gte('created_at', `${year}-01-01`)
  const seq = String((count ?? 0) + 1).padStart(4, '0')
  return `LN-${year}-${seq}`
}

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Unauthorized' }, 401)

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const { data: member } = await supabase
      .from('members')
      .select('id, status')
      .eq('user_id', user.id)
      .single()

    if (!member) return json({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return json({ error: 'Your account is not active' }, 403)

    const body = await req.json()

    if (body.action === 'apply')       return await applyLoan(member.id, body)
    if (body.action === 'eligibility') return await getEligibility(member.id)
    if (body.action === 'schedule')    return await getLoanSchedule(member.id, body)
    if (body.action === 'products')    return await listProducts()

    return json({ error: 'Invalid action' }, 400)
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
    supabase.from('loans').select('id, loan_number, loan_type, status').eq('member_id', memberId).in('status', ['pending', 'approved', 'disbursed']).maybeSingle(),
  ])

  const bosa = bosaRes.data
  const fosa = fosaRes.data
  const activeLoan = activeLoanRes.data

  const bosaSavings = parseFloat(bosa?.savings_balance ?? '0')
  const hasSalary = fosa?.salary_amount > 0

  return json({
    bosa_savings: bosaSavings,
    has_salary_via_fosa: hasSalary,
    active_loan: activeLoan ?? null,
    limits: {
      bosa_5x: parseFloat((bosaSavings * 5).toFixed(2)),
      bosa_4x: parseFloat((bosaSavings * 4).toFixed(2)),
    },
    can_apply: !activeLoan,
  })
}

// ── Schedule for existing loan ────────────────────────────────────────────────
async function getLoanSchedule(memberId: string, body: any) {
  const { loan_id } = body
  if (!loan_id) return json({ error: 'loan_id required' }, 400)

  const { data: loan } = await supabase
    .from('loans')
    .select('*')
    .eq('id', loan_id)
    .eq('member_id', memberId)
    .single()

  if (!loan) return json({ error: 'Loan not found' }, 404)

  const product = LOAN_PRODUCTS[loan.loan_type]
  if (!product) return json({ error: 'Unknown loan type' }, 400)

  const schedule = buildSchedule(
    product,
    parseFloat(loan.principal),
    loan.duration_months,
    parseFloat(loan.monthly_repayment)
  )

  return json({ schedule })
}

// ── List products ─────────────────────────────────────────────────────────────
async function listProducts() {
  const products = Object.entries(LOAN_PRODUCTS).map(([key, p]) => ({
    loan_type: key,
    display_name: p.displayName,
    category: p.category,
    max_months: p.maxMonths,
    deposit_multiplier: p.depositMultiplier,
    interest_rate_pa: p.interestRatePa,
    monthly_rate: p.monthlyRate ?? null,
    interest_type: p.interestType,
    commission_pct: p.commissionPct,
    max_amount: p.maxAmount ?? null,
    salary_required: p.salaryRequired,
    no_dividends: p.noDividends,
  }))
  return json({ products })
}

// ── Apply ─────────────────────────────────────────────────────────────────────
async function applyLoan(memberId: string, body: any) {
  const { loan_type, principal, duration_months, purpose } = body

  const product = LOAN_PRODUCTS[loan_type as string]
  if (!product) return json({ error: 'Invalid loan type' }, 400)

  if (!principal || principal < 1000) return json({ error: 'Minimum loan amount is KES 1,000' }, 400)
  if (!duration_months || duration_months < 1 || duration_months > product.maxMonths) {
    return json({ error: `${product.displayName} repayment period is max ${product.maxMonths} months` }, 400)
  }
  if (product.maxAmount && principal > product.maxAmount) {
    return json({ error: `${product.displayName} maximum is KES ${product.maxAmount.toLocaleString()}` }, 400)
  }

  const { data: fosa } = await supabase
    .from('fosa_accounts')
    .select('id, salary_amount')
    .eq('member_id', memberId)
    .single()

  if (!fosa) return json({ error: 'FOSA account not found. All loans are disbursed through FOSA.' }, 404)

  if (product.salaryRequired && (!fosa.salary_amount || fosa.salary_amount <= 0)) {
    return json({ error: `${product.displayName} is only available to members whose salary is processed through FOSA` }, 400)
  }

  if (product.depositMultiplier > 0) {
    const { data: bosa } = await supabase
      .from('bosa_accounts')
      .select('savings_balance, is_active')
      .eq('member_id', memberId)
      .single()

    if (!bosa) return json({ error: 'BOSA account not found' }, 404)
    if (!bosa.is_active) return json({ error: 'Your BOSA account is not active' }, 403)

    const loanLimit = bosa.savings_balance * product.depositMultiplier
    if (loanLimit <= 0) return json({ error: 'You have no BOSA deposits to qualify for this loan' }, 400)
    if (principal > loanLimit) {
      return json({
        error: `Loan exceeds your limit of KES ${loanLimit.toFixed(2)} (${product.depositMultiplier}× your BOSA deposits of KES ${bosa.savings_balance.toFixed(2)})`
      }, 400)
    }
  }

  if (loan_type === 'dividend_advance') {
    const lastYear = new Date().getFullYear() - 1
    const { data: divTx } = await supabase
      .from('transactions')
      .select('amount')
      .eq('member_id', memberId)
      .eq('transaction_type', 'dividend')
      .gte('created_at', `${lastYear}-01-01`)
      .lte('created_at', `${lastYear}-12-31`)
    const totalDiv = (divTx ?? []).reduce((s: number, t: any) => s + parseFloat(t.amount), 0)
    const maxAdvance = totalDiv * 0.5
    if (maxAdvance <= 0) return json({ error: 'You did not receive dividends last year' }, 400)
    if (principal > maxAdvance) {
      return json({ error: `Dividend advance capped at 50% of your ${lastYear} dividends: KES ${maxAdvance.toFixed(2)}` }, 400)
    }
  }

  const { data: existingLoan } = await supabase
    .from('loans')
    .select('id, loan_number')
    .eq('member_id', memberId)
    .in('status', ['pending', 'approved', 'disbursed'])
    .maybeSingle()

  if (existingLoan) {
    return json({ error: `You already have an active loan (${existingLoan.loan_number}). Clear it before applying again.` }, 400)
  }

  let repayment = calcRepayment(product, principal, duration_months)

  if (loan_type === 'qcash') {
    const charge = principal * 0.05
    repayment = { monthly: parseFloat(((principal + charge) / 2).toFixed(2)), total: parseFloat((principal + charge).toFixed(2)), commission: parseFloat(charge.toFixed(2)) }
  } else if (loan_type === 'dividend_advance') {
    const charge = principal * 0.10
    repayment = { monthly: parseFloat((principal + charge).toFixed(2)), total: parseFloat((principal + charge).toFixed(2)), commission: parseFloat(charge.toFixed(2)) }
  }

  const loanNumber = await nextLoanNumber()

  const { data: loan, error } = await supabase
    .from('loans')
    .insert({
      member_id: memberId,
      loan_number: loanNumber,
      loan_type,
      principal,
      commission_amount: repayment.commission,
      interest_rate: product.interestRatePa,
      duration_months,
      monthly_repayment: repayment.monthly,
      total_repayable: repayment.total,
      outstanding_balance: repayment.total,
      purpose: purpose ?? '',
      status: 'pending',
      disbursed_to_fosa_id: fosa.id,
    })
    .select()
    .single()

  if (error) {
    console.error('[LOAN] Insert error:', error.message)
    return json({ error: 'Failed to submit loan application' }, 500)
  }

  // Build schedule for the response
  const schedule = buildSchedule(product, principal, duration_months, repayment.monthly)

  return json({
    success: true,
    loan,
    summary: {
      monthly_repayment: repayment.monthly,
      total_repayable: repayment.total,
      total_interest: parseFloat((repayment.total - principal).toFixed(2)),
      commission: repayment.commission,
      no_dividends: product.noDividends,
    },
    schedule,
  })
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
