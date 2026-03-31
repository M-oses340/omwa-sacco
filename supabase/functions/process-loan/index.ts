// deno-lint-ignore-file no-explicit-any
// Business rules encoded here mirror the loan_products table.
// All loans disbursed through FOSA.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// ── Loan product definitions (mirrors loan_products table) ──────────────────
interface LoanProduct {
  displayName: string
  category: 'bosa' | 'fosa_advance' | 'special'
  maxMonths: number
  depositMultiplier: number   // 0 = not deposit-based
  interestRatePa: number      // annual %; 0 for Muslim/Q-Cash
  interestType: 'reducing_balance' | 'flat_monthly' | 'flat_disbursement' | 'none'
  monthlyRate?: number        // for FOSA advances (flat monthly %)
  commissionPct: number       // one-off % of principal (Muslim loans)
  maxAmount?: number          // hard cap (Q-Cash = 40000)
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

// ── Repayment calculator ─────────────────────────────────────────────────────
function calcRepayment(product: LoanProduct, principal: number, months: number) {
  let monthly = 0
  let total = 0
  let commission = 0

  switch (product.interestType) {
    case 'reducing_balance': {
      // Use monthlyRate if set (FOSA Golden), else derive from annual
      const mr = product.monthlyRate
        ? product.monthlyRate / 100
        : product.interestRatePa / 100 / 12
      monthly = (principal * mr * Math.pow(1 + mr, months)) /
                (Math.pow(1 + mr, months) - 1)
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
      // Overridden per-product below (qcash / dividend_advance)
      total = principal
      monthly = principal / months
      break
    }
    case 'none': {
      // Muslim loans: no interest, just commission
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

// ── Main handler ─────────────────────────────────────────────────────────────
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
    if (body.action === 'apply') return await applyLoan(member.id, body)
    if (body.action === 'products') return await listProducts()

    return json({ error: 'Invalid action' }, 400)
  } catch (e) {
    console.error('[LOAN] Error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

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

// ── Apply for a loan ──────────────────────────────────────────────────────────
async function applyLoan(memberId: string, body: any) {
  const { loan_type, principal, duration_months, purpose } = body

  const product = LOAN_PRODUCTS[loan_type as string]
  if (!product) return json({ error: 'Invalid loan type' }, 400)

  if (!principal || principal < 1000) {
    return json({ error: 'Minimum loan amount is KES 1,000' }, 400)
  }
  if (!duration_months || duration_months < 1 || duration_months > product.maxMonths) {
    return json({
      error: `${product.displayName} repayment period is max ${product.maxMonths} months`
    }, 400)
  }

  // Hard amount cap (Q-Cash)
  if (product.maxAmount && principal > product.maxAmount) {
    return json({
      error: `${product.displayName} maximum is KES ${product.maxAmount.toLocaleString()}`
    }, 400)
  }

  // Fetch FOSA — all disbursements go here
  const { data: fosa } = await supabase
    .from('fosa_accounts')
    .select('id, salary_amount')
    .eq('member_id', memberId)
    .single()

  if (!fosa) return json({ error: 'FOSA account not found. All loans are disbursed through FOSA.' }, 404)

  // Salary-based products require salary through FOSA
  if (product.salaryRequired && (!fosa.salary_amount || fosa.salary_amount <= 0)) {
    return json({
      error: `${product.displayName} is only available to members whose salary is processed through FOSA`
    }, 400)
  }

  // BOSA deposit-based limit check
  if (product.depositMultiplier > 0) {
    const { data: bosa } = await supabase
      .from('bosa_accounts')
      .select('savings_balance')
      .eq('member_id', memberId)
      .single()

    if (!bosa) return json({ error: 'BOSA account not found' }, 404)

    const loanLimit = bosa.savings_balance * product.depositMultiplier
    if (loanLimit <= 0) {
      return json({ error: 'You have no BOSA deposits to qualify for this loan' }, 400)
    }
    if (principal > loanLimit) {
      return json({
        error: `Loan exceeds your limit of KES ${loanLimit.toFixed(2)} (${product.depositMultiplier}× your BOSA deposits of KES ${bosa.savings_balance.toFixed(2)})`
      }, 400)
    }
  }

  // Dividend advance: cap at 50% of prior-year dividends
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
    if (maxAdvance <= 0) {
      return json({ error: 'You did not receive dividends last year' }, 400)
    }
    if (principal > maxAdvance) {
      return json({
        error: `Dividend advance capped at 50% of your ${lastYear} dividends: KES ${maxAdvance.toFixed(2)}`
      }, 400)
    }
  }

  // Block if active loan exists (same category)
  const { data: existingLoan } = await supabase
    .from('loans')
    .select('id, loan_number, loan_type')
    .eq('member_id', memberId)
    .in('status', ['pending', 'approved', 'disbursed'])
    .maybeSingle()

  if (existingLoan) {
    return json({
      error: `You already have an active loan (${existingLoan.loan_number}). Clear it before applying again.`
    }, 400)
  }

  // Calculate repayment
  let repayment = calcRepayment(product, principal, duration_months)

  // Override flat_disbursement rates per product
  if (loan_type === 'qcash') {
    const charge = principal * 0.05
    repayment = {
      monthly: parseFloat(((principal + charge) / 2).toFixed(2)),
      total: parseFloat((principal + charge).toFixed(2)),
      commission: parseFloat(charge.toFixed(2)),
    }
  } else if (loan_type === 'dividend_advance') {
    const charge = principal * 0.10
    repayment = {
      monthly: parseFloat((principal + charge).toFixed(2)),
      total: parseFloat((principal + charge).toFixed(2)),
      commission: parseFloat(charge.toFixed(2)),
    }
  }

  const loanNumber = `LN-${Date.now()}`

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

  return json({
    success: true,
    loan,
    summary: {
      monthly_repayment: repayment.monthly,
      total_repayable: repayment.total,
      commission: repayment.commission,
      no_dividends: product.noDividends,
    },
  })
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
