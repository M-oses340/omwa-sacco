// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const R = (d: unknown, s = 200) =>
  new Response(JSON.stringify(d), { status: s, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })

const CORS_HEADERS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }

// ── Auth ──────────────────────────────────────────────────────────────────────
function getUserId(req: Request, body: any): string | null {
  const raw = req.headers.get('Authorization') ?? (body?.jwt ? `Bearer ${body.jwt}` : null)
  if (!raw?.startsWith('Bearer ')) return null
  try {
    const parts = raw.slice(7).split('.')
    if (parts.length !== 3) return null
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const pad = b64.length % 4 === 0 ? '' : '='.repeat(4 - b64.length % 4)
    const p = JSON.parse(atob(b64 + pad))
    if (p.role !== 'authenticated') return null
    if (p.exp && p.exp < Math.floor(Date.now() / 1000)) return null
    return p.sub ?? null
  } catch { return null }
}

const ADMIN_ROLES = ['admin', 'treasurer', 'chairman']

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS })
  let body: any
  try { body = await req.json() } catch { return R({ error: 'Invalid JSON' }, 400) }

  const uid = getUserId(req, body)
  if (!uid) return R({ error: 'Unauthorized' }, 401)

  try {
    const { data: member } = await db.from('members')
      .select('id, status, role').eq('user_id', uid).single()
    if (!member) return R({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return R({ error: 'Account not active' }, 403)

    const isAdmin = ADMIN_ROLES.includes(member.role)
    const { report, params } = body

    // Member-only reports (no admin required)
    switch (report) {
      case 'member_statement': return await memberStatement(member.id, params)
      case 'my_savings':       return await mySavings(member.id)
      case 'my_transactions':  return await memberStatement(member.id, params)
      case 'loan_repayments':  return await loanRepayments(member.id, params)
    }

    // Admin-only reports
    if (!isAdmin) return R({ error: 'Forbidden' }, 403)

    switch (report) {
      case 'member_register':       return await memberRegister(params)
      case 'new_members':           return await newMembers(params)
      case 'dormant_members':       return await dormantMembers()
      case 'savings_summary':       return await savingsSummary()
      case 'deposit_collection':    return await depositCollection(params)
      case 'fosa_balances':         return await fosaBalances()
      case 'loan_book':             return await loanBook()
      case 'loan_disbursements':    return await loanDisbursements(params)
      case 'arrears':               return await arrearsReport()
      case 'npl':                   return await nplReport()
      case 'par':                   return await parReport()
      case 'income_statement':      return await incomeStatement(params)
      case 'balance_sheet':         return await balanceSheet()
      case 'cash_flow':             return await cashFlow(params)
      case 'withdrawal_report':     return await withdrawalReport(params)
      case 'daily_summary':         return await dailySummary(params)
      case 'mpesa_reconciliation':  return await mpesaReconciliation(params)
      case 'share_capital':         return await shareCapital()
      case 'dividend_report':       return await dividendReport(params)
      case 'pending_approvals':     return await pendingApprovals()
      case 'audit_trail':           return await auditTrail(params)
      case 'teller_reconciliation': return await tellerReconciliation(params)
      default: return R({ error: 'Unknown report' }, 400)
    }
  } catch (e) {
    console.error('[REPORTS]', (e as Error).message)
    return R({ error: (e as Error).message }, 500)
  }
})

// ── Helpers ───────────────────────────────────────────────────────────────────
function dateFilter(params: any) {
  const start = params?.start_date
  const end   = params?.end_date
  return { start, end }
}

function applyDateFilter(q: any, col: string, start?: string, end?: string) {
  if (start) q = q.gte(col, start)
  if (end)   q = q.lte(col, end)
  return q
}

// ── Member reports ────────────────────────────────────────────────────────────
async function memberStatement(memberId: string, params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions').select('*').eq('member_id', memberId).order('created_at', { ascending: false })
  q = applyDateFilter(q, 'created_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)

  // Compute running balance
  const rows = (data ?? []).reverse()
  let balance = 0
  const creditTypes = ['deposit', 'loan_disbursement', 'dividend']
  const withBalance = rows.map((tx: any) => {
    const amt = parseFloat(tx.amount)
    balance += creditTypes.includes(tx.transaction_type) ? amt : -amt
    return { ...tx, running_balance: +balance.toFixed(2) }
  }).reverse()

  return R({ data: withBalance, count: withBalance.length })
}

async function mySavings(memberId: string) {
  const [bosaRes, fosaRes] = await Promise.all([
    db.from('bosa_accounts').select('*').eq('member_id', memberId).maybeSingle(),
    db.from('fosa_accounts').select('*').eq('member_id', memberId).maybeSingle(),
  ])
  const rows: any[] = []
  if (bosaRes.data) {
    rows.push({ account: 'BOSA Savings', balance: bosaRes.data.savings_balance, status: bosaRes.data.status })
    rows.push({ account: 'BOSA Shares',  balance: bosaRes.data.shares_balance,  status: bosaRes.data.status })
  }
  if (fosaRes.data) {
    rows.push({ account: 'FOSA', balance: fosaRes.data.balance, status: fosaRes.data.status })
  }
  return R({ data: rows, count: rows.length })
}

async function loanRepayments(memberId: string, params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('loan_repayments')
    .select('*, loans(loan_number, loan_type, principal, due_date)')
    .eq('member_id', memberId).order('created_at', { ascending: false })
  q = applyDateFilter(q, 'due_date', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return R({ data: data ?? [], count: (data ?? []).length })
}

// ── Admin: Member reports ─────────────────────────────────────────────────────
async function memberRegister(params: any) {
  let q = db.from('members')
    .select('member_number, full_name, phone_number, status, created_at, bosa_accounts(savings_balance, shares_balance), fosa_accounts(balance)')
    .order('member_number')
  if (params?.status) q = q.eq('status', params.status)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return R({ data: data ?? [], count: (data ?? []).length })
}

async function newMembers(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('members')
    .select('member_number, full_name, phone_number, created_at, status')
    .order('created_at', { ascending: false })
  q = applyDateFilter(q, 'created_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return R({ data: data ?? [], count: (data ?? []).length })
}

async function dormantMembers() {
  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() - 90)
  const { data, error } = await db.from('members')
    .select('member_number, full_name, phone_number, last_activity_at, bosa_accounts(savings_balance), fosa_accounts(balance)')
    .lt('last_activity_at', cutoff.toISOString())
    .eq('status', 'active')
  if (error) throw new Error(error.message)
  return R({ data: data ?? [], count: (data ?? []).length })
}

// ── Admin: Savings reports ────────────────────────────────────────────────────
async function savingsSummary() {
  const { data, error } = await db.from('bosa_accounts')
    .select('members!bosa_accounts_member_id_fkey(member_number, full_name), savings_balance, shares_balance, status')
    .order('savings_balance', { ascending: false })
  if (error) throw new Error(error.message)

  const rows = data ?? []
  const totalSavings = rows.reduce((s: number, r: any) => s + parseFloat(r.savings_balance ?? 0), 0)
  const totalShares  = rows.reduce((s: number, r: any) => s + parseFloat(r.shares_balance ?? 0), 0)
  return R({ data: rows, count: rows.length, summary: { total_savings: +totalSavings.toFixed(2), total_shares: +totalShares.toFixed(2) } })
}

async function depositCollection(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions')
    .select('created_at, members!transactions_member_id_fkey(full_name, member_number), amount, payment_method, status, reference')
    .eq('transaction_type', 'deposit').order('created_at', { ascending: false })
  q = applyDateFilter(q, 'created_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const total = rows.filter((r: any) => r.status === 'completed').reduce((s: number, r: any) => s + parseFloat(r.amount), 0)
  return R({ data: rows, count: rows.length, summary: { total_collected: +total.toFixed(2) } })
}

async function fosaBalances() {
  const { data, error } = await db.from('fosa_accounts')
    .select('account_number, members!fosa_accounts_member_id_fkey(full_name, member_number), balance, status')
    .order('balance', { ascending: false })
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const total = rows.reduce((s: number, r: any) => s + parseFloat(r.balance ?? 0), 0)
  return R({ data: rows, count: rows.length, summary: { total_balance: +total.toFixed(2) } })
}

// ── Admin: Loan reports ───────────────────────────────────────────────────────
async function loanBook() {
  const { data, error } = await db.from('loans')
    .select('members!loans_member_id_fkey(full_name, member_number), loan_number, loan_type, principal, outstanding_balance, monthly_repayment, due_date, disbursed_at, status')
    .in('status', ['disbursed', 'active']).order('outstanding_balance', { ascending: false })
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const totalPortfolio  = rows.reduce((s: number, r: any) => s + parseFloat(r.principal ?? 0), 0)
  const totalOutstanding = rows.reduce((s: number, r: any) => s + parseFloat(r.outstanding_balance ?? 0), 0)
  return R({ data: rows, count: rows.length, summary: { total_portfolio: +totalPortfolio.toFixed(2), total_outstanding: +totalOutstanding.toFixed(2) } })
}

async function loanDisbursements(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('loans')
    .select('disbursed_at, members!loans_member_id_fkey(full_name, member_number), loan_number, loan_type, principal, status')
    .eq('status', 'disbursed').order('disbursed_at', { ascending: false })
  q = applyDateFilter(q, 'disbursed_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const total = rows.reduce((s: number, r: any) => s + parseFloat(r.principal ?? 0), 0)
  return R({ data: rows, count: rows.length, summary: { total_disbursed: +total.toFixed(2) } })
}

async function arrearsReport() {
  const today = new Date().toISOString().split('T')[0]
  const { data, error } = await db.from('loans')
    .select('members!loans_member_id_fkey(full_name, member_number), loan_number, loan_type, outstanding_balance, monthly_repayment, due_date, status')
    .in('status', ['disbursed', 'defaulted']).lt('due_date', today)
    .order('due_date')
  if (error) throw new Error(error.message)
  const rows = (data ?? []).map((r: any) => {
    const daysOverdue = Math.max(0, Math.floor((Date.now() - new Date(r.due_date).getTime()) / 86400000))
    return { ...r, days_overdue: daysOverdue, bucket: daysOverdue <= 30 ? '1-30' : daysOverdue <= 60 ? '31-60' : daysOverdue <= 90 ? '61-90' : '90+' }
  })
  const totalArrears = rows.reduce((s: number, r: any) => s + parseFloat(r.outstanding_balance ?? 0), 0)
  return R({ data: rows, count: rows.length, summary: { total_arrears: +totalArrears.toFixed(2) } })
}

async function nplReport() {
  const { data, error } = await db.from('loans')
    .select('members!loans_member_id_fkey(full_name, member_number), loan_number, loan_type, principal, outstanding_balance, due_date')
    .eq('status', 'defaulted')
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const totalNpl = rows.reduce((s: number, r: any) => s + parseFloat(r.outstanding_balance ?? 0), 0)
  return R({ data: rows, count: rows.length, summary: { total_npl: +totalNpl.toFixed(2) } })
}

async function parReport() {
  const [bookRes, arrearsRes] = await Promise.all([
    db.from('loans').select('loan_type, principal').in('status', ['disbursed', 'active']),
    db.from('loans').select('loan_type, outstanding_balance').in('status', ['disbursed', 'defaulted']).lt('due_date', new Date().toISOString().split('T')[0]),
  ])
  const portfolio: Record<string, number> = {}
  const atRisk: Record<string, number> = {}
  for (const r of bookRes.data ?? []) {
    portfolio[r.loan_type] = (portfolio[r.loan_type] ?? 0) + parseFloat(r.principal)
  }
  for (const r of arrearsRes.data ?? []) {
    atRisk[r.loan_type] = (atRisk[r.loan_type] ?? 0) + parseFloat(r.outstanding_balance)
  }
  const totalPortfolio = Object.values(portfolio).reduce((a, b) => a + b, 0)
  const totalAtRisk    = Object.values(atRisk).reduce((a, b) => a + b, 0)
  const rows = Object.keys(portfolio).map(type => ({
    loan_type: type,
    total_portfolio: +portfolio[type].toFixed(2),
    at_risk: +(atRisk[type] ?? 0).toFixed(2),
    par_pct: portfolio[type] > 0 ? +((atRisk[type] ?? 0) / portfolio[type] * 100).toFixed(2) : 0,
  }))
  return R({ data: rows, count: rows.length, summary: { total_portfolio: +totalPortfolio.toFixed(2), total_at_risk: +totalAtRisk.toFixed(2), par_pct: totalPortfolio > 0 ? +(totalAtRisk / totalPortfolio * 100).toFixed(2) : 0 } })
}

// ── Admin: Financial reports ──────────────────────────────────────────────────
async function incomeStatement(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions').select('transaction_type, amount, status')
  q = applyDateFilter(q, 'created_at', start, end)
  const { data } = await q
  const rows = (data ?? []).filter((r: any) => r.status === 'completed')

  const agg: Record<string, number> = {}
  for (const r of rows) {
    agg[r.transaction_type] = (agg[r.transaction_type] ?? 0) + parseFloat(r.amount)
  }

  // Interest income from loans
  const loanQ = applyDateFilter(
    db.from('loans').select('loan_type, principal, interest_rate, duration_months').eq('status', 'disbursed'),
    'disbursed_at', start, end
  )
  const { data: loans } = await loanQ
  const interestIncome = (loans ?? []).reduce((s: number, l: any) => {
    const monthly = parseFloat(l.principal) * (parseFloat(l.interest_rate) / 12 / 100)
    return s + monthly * parseFloat(l.duration_months)
  }, 0)

  const statement = [
    { category: 'Income', description: 'Interest Income (Loans)', amount: +interestIncome.toFixed(2) },
    { category: 'Income', description: 'Loan Commission Fees', amount: +(agg['commission'] ?? 0).toFixed(2) },
    { category: 'Income', description: 'Transfer Fees', amount: +(agg['transfer_fee'] ?? 0).toFixed(2) },
    { category: 'Expenses', description: 'M-Pesa Withdrawal Costs', amount: +(agg['withdrawal'] ?? 0 * 0.01).toFixed(2) },
    { category: 'Expenses', description: 'Dividends Paid', amount: +(agg['dividend'] ?? 0).toFixed(2) },
  ]
  const totalIncome   = statement.filter(r => r.category === 'Income').reduce((s, r) => s + r.amount, 0)
  const totalExpenses = statement.filter(r => r.category === 'Expenses').reduce((s, r) => s + r.amount, 0)
  return R({ data: statement, count: statement.length, summary: { total_income: +totalIncome.toFixed(2), total_expenses: +totalExpenses.toFixed(2), net: +(totalIncome - totalExpenses).toFixed(2) } })
}

async function balanceSheet() {
  const [bosaRes, fosaRes, loansRes] = await Promise.all([
    db.from('bosa_accounts').select('savings_balance, shares_balance'),
    db.from('fosa_accounts').select('balance'),
    db.from('loans').select('outstanding_balance').in('status', ['disbursed', 'active']),
  ])
  const totalSavings  = (bosaRes.data ?? []).reduce((s: number, r: any) => s + parseFloat(r.savings_balance ?? 0), 0)
  const totalShares   = (bosaRes.data ?? []).reduce((s: number, r: any) => s + parseFloat(r.shares_balance ?? 0), 0)
  const totalFosa     = (fosaRes.data ?? []).reduce((s: number, r: any) => s + parseFloat(r.balance ?? 0), 0)
  const totalLoans    = (loansRes.data ?? []).reduce((s: number, r: any) => s + parseFloat(r.outstanding_balance ?? 0), 0)

  const rows = [
    { category: 'Assets', item: 'Loan Portfolio (Outstanding)', amount: +totalLoans.toFixed(2) },
    { category: 'Assets', item: 'FOSA Cash Holdings', amount: +totalFosa.toFixed(2) },
    { category: 'Liabilities', item: 'Member Savings (BOSA)', amount: +totalSavings.toFixed(2) },
    { category: 'Equity', item: 'Share Capital', amount: +totalShares.toFixed(2) },
  ]
  const totalAssets      = rows.filter(r => r.category === 'Assets').reduce((s, r) => s + r.amount, 0)
  const totalLiabilities = rows.filter(r => r.category === 'Liabilities').reduce((s, r) => s + r.amount, 0)
  const totalEquity      = rows.filter(r => r.category === 'Equity').reduce((s, r) => s + r.amount, 0)
  return R({ data: rows, count: rows.length, summary: { total_assets: +totalAssets.toFixed(2), total_liabilities: +totalLiabilities.toFixed(2), total_equity: +totalEquity.toFixed(2) } })
}

async function cashFlow(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions').select('transaction_type, amount, status, created_at')
  q = applyDateFilter(q, 'created_at', start, end)
  const { data } = await q
  const completed = (data ?? []).filter((r: any) => r.status === 'completed')

  const inflows  = ['deposit', 'loan_repayment']
  const outflows = ['withdrawal', 'loan_disbursement', 'dividend', 'transfer']
  const agg: Record<string, number> = {}
  for (const r of completed) {
    agg[r.transaction_type] = (agg[r.transaction_type] ?? 0) + parseFloat(r.amount)
  }
  const rows = [
    ...inflows.map(t => ({ category: 'Inflow', description: t.replaceAll('_', ' '), amount: +(agg[t] ?? 0).toFixed(2) })),
    ...outflows.map(t => ({ category: 'Outflow', description: t.replaceAll('_', ' '), amount: +(agg[t] ?? 0).toFixed(2) })),
  ]
  const totalIn  = rows.filter(r => r.category === 'Inflow').reduce((s, r) => s + r.amount, 0)
  const totalOut = rows.filter(r => r.category === 'Outflow').reduce((s, r) => s + r.amount, 0)
  return R({ data: rows, count: rows.length, summary: { total_inflow: +totalIn.toFixed(2), total_outflow: +totalOut.toFixed(2), net_cash_flow: +(totalIn - totalOut).toFixed(2) } })
}

// ── Admin: Transaction reports ────────────────────────────────────────────────
async function withdrawalReport(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions')
    .select('created_at, members!transactions_member_id_fkey(full_name, member_number), amount, payment_method, status, reference')
    .in('transaction_type', ['withdrawal']).order('created_at', { ascending: false })
  q = applyDateFilter(q, 'created_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const total = rows.filter((r: any) => r.status === 'completed').reduce((s: number, r: any) => s + parseFloat(r.amount), 0)
  return R({ data: rows, count: rows.length, summary: { total_withdrawn: +total.toFixed(2) } })
}

async function dailySummary(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions').select('created_at, transaction_type, amount, status')
  q = applyDateFilter(q, 'created_at', start, end)
  const { data } = await q
  const byDay: Record<string, any> = {}
  for (const r of data ?? []) {
    const day = r.created_at.split('T')[0]
    if (!byDay[day]) byDay[day] = { date: day, deposits: 0, withdrawals: 0, transfers: 0, loan_disbursements: 0, loan_repayments: 0, net: 0 }
    const amt = parseFloat(r.amount)
    if (r.status !== 'completed') continue
    if (r.transaction_type === 'deposit')          byDay[day].deposits += amt
    else if (r.transaction_type.includes('withdrawal')) byDay[day].withdrawals += amt
    else if (r.transaction_type === 'transfer')    byDay[day].transfers += amt
    else if (r.transaction_type === 'loan_disbursement') byDay[day].loan_disbursements += amt
    else if (r.transaction_type === 'loan_repayment')    byDay[day].loan_repayments += amt
    byDay[day].net = byDay[day].deposits + byDay[day].loan_repayments - byDay[day].withdrawals - byDay[day].loan_disbursements
  }
  const rows = Object.values(byDay).sort((a: any, b: any) => b.date.localeCompare(a.date))
    .map((r: any) => ({ ...r, deposits: +r.deposits.toFixed(2), withdrawals: +r.withdrawals.toFixed(2), transfers: +r.transfers.toFixed(2), loan_disbursements: +r.loan_disbursements.toFixed(2), loan_repayments: +r.loan_repayments.toFixed(2), net: +r.net.toFixed(2) }))
  return R({ data: rows, count: rows.length })
}

async function mpesaReconciliation(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions')
    .select('created_at, reference, members!transactions_member_id_fkey(full_name, member_number), amount, status, transaction_type')
    .eq('payment_method', 'mpesa').order('created_at', { ascending: false })
  q = applyDateFilter(q, 'created_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const reconciled   = rows.filter((r: any) => r.status === 'completed').length
  const unreconciled = rows.filter((r: any) => r.status === 'pending').length
  return R({ data: rows, count: rows.length, summary: { reconciled, unreconciled } })
}

// ── Admin: Compliance reports ─────────────────────────────────────────────────
async function shareCapital() {
  const { data, error } = await db.from('bosa_accounts')
    .select('members!bosa_accounts_member_id_fkey(member_number, full_name), shares_balance, status')
    .order('shares_balance', { ascending: false })
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const total = rows.reduce((s: number, r: any) => s + parseFloat(r.shares_balance ?? 0), 0)
  return R({ data: rows, count: rows.length, summary: { total_share_capital: +total.toFixed(2) } })
}

async function dividendReport(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions')
    .select('created_at, members!transactions_member_id_fkey(member_number, full_name), amount, status')
    .eq('transaction_type', 'dividend').order('created_at', { ascending: false })
  q = applyDateFilter(q, 'created_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  const rows = data ?? []
  const total = rows.filter((r: any) => r.status === 'completed').reduce((s: number, r: any) => s + parseFloat(r.amount), 0)
  return R({ data: rows, count: rows.length, summary: { total_dividends: +total.toFixed(2) } })
}

// ── Admin: Operational reports ────────────────────────────────────────────────
async function pendingApprovals() {
  const { data, error } = await db.from('loans')
    .select('loan_type, members!loans_member_id_fkey(full_name, member_number), loan_number, principal, created_at, status')
    .eq('status', 'pending').order('created_at', { ascending: false })
  if (error) throw new Error(error.message)
  return R({ data: data ?? [], count: (data ?? []).length })
}

async function auditTrail(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(500)
  q = applyDateFilter(q, 'created_at', start, end)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return R({ data: data ?? [], count: (data ?? []).length })
}

async function tellerReconciliation(params: any) {
  const { start, end } = dateFilter(params)
  let q = db.from('transactions')
    .select('created_at, transaction_type, amount, status, created_by')
  q = applyDateFilter(q, 'created_at', start, end)
  const { data } = await q
  const byTeller: Record<string, any> = {}
  for (const r of data ?? []) {
    const teller = r.created_by ?? 'system'
    if (!byTeller[teller]) byTeller[teller] = { teller, cash_in: 0, cash_out: 0 }
    const amt = parseFloat(r.amount)
    if (r.status !== 'completed') continue
    if (['deposit', 'loan_repayment'].includes(r.transaction_type)) byTeller[teller].cash_in += amt
    else byTeller[teller].cash_out += amt
  }
  const rows = Object.values(byTeller).map((r: any) => ({
    teller: r.teller,
    cash_in: +r.cash_in.toFixed(2),
    cash_out: +r.cash_out.toFixed(2),
    net: +(r.cash_in - r.cash_out).toFixed(2),
  }))
  return R({ data: rows, count: rows.length })
}
