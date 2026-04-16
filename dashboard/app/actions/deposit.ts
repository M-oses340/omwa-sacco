'use server'
import { createClient } from '@supabase/supabase-js'

// Service role client — only used server-side, never exposed to the browser
const admin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

type AccountType = 'fosa' | 'bosa_savings' | 'bosa_shares'
type PaymentMethod = 'cash' | 'cheque' | 'bank_transfer' | 'mpesa'

const ACCOUNT_LABELS: Record<AccountType, string> = {
  fosa: 'FOSA (Current Account)',
  bosa_savings: 'BOSA Savings',
  bosa_shares: 'BOSA Shares',
}

export async function postDeposit(params: {
  memberId: string
  memberName: string
  accountType: AccountType
  amount: number
  method: PaymentMethod
  reference?: string
  notes?: string
}): Promise<{ ok: boolean; error?: string }> {
  const { memberId, memberName, accountType, amount, method, reference, notes } = params
  const ref = reference || `MAN-${Date.now()}`

  try {
    if (accountType === 'fosa') {
      const { data: fosa, error: fErr } = await admin
        .from('fosa_accounts').select('id, balance').eq('member_id', memberId).single()
      if (fErr || !fosa) return { ok: false, error: 'FOSA account not found' }

      const newBal = +(parseFloat(fosa.balance) + amount).toFixed(2)

      const { error: uErr } = await admin
        .from('fosa_accounts').update({ balance: newBal }).eq('id', fosa.id)
      if (uErr) return { ok: false, error: uErr.message }

      const { error: tErr } = await admin.from('transactions').insert({
        member_id: memberId, account_type: 'fosa', transaction_type: 'deposit',
        amount, balance_before: fosa.balance, balance_after: newBal,
        reference: ref,
        description: notes || `Manual ${method} deposit`,
        status: 'completed', payment_method: method,
      })
      if (tErr) return { ok: false, error: tErr.message }

    } else {
      const { data: bosa, error: bErr } = await admin
        .from('bosa_accounts').select('id, savings_balance, shares_balance').eq('member_id', memberId).single()
      if (bErr || !bosa) return { ok: false, error: 'BOSA account not found' }

      const field = accountType === 'bosa_savings' ? 'savings_balance' : 'shares_balance'
      const current = parseFloat(bosa[field as keyof typeof bosa] as string)
      const newBal = +(current + amount).toFixed(2)

      const { error: uErr } = await admin
        .from('bosa_accounts').update({ [field]: newBal }).eq('id', bosa.id)
      if (uErr) return { ok: false, error: uErr.message }

      const { error: tErr } = await admin.from('transactions').insert({
        member_id: memberId, account_type: 'bosa',
        transaction_type: accountType === 'bosa_savings' ? 'bosa_deposit' : 'shares_deposit',
        amount, balance_before: current, balance_after: newBal,
        reference: ref,
        description: notes || `Manual ${method} deposit to ${ACCOUNT_LABELS[accountType]}`,
        status: 'completed', payment_method: method,
      })
      if (tErr) return { ok: false, error: tErr.message }
    }

    // In-app notification (best-effort)
    await admin.from('notifications').insert({
      member_id: memberId, type: 'payment',
      title: 'Deposit Received 💵',
      body: `KES ${amount.toLocaleString()} has been deposited to your ${ACCOUNT_LABELS[accountType]} account.`,
      is_read: false,
    })

    return { ok: true }
  } catch (e: any) {
    return { ok: false, error: e.message ?? 'Unknown error' }
  }
}

export async function postBulkDeposit(rows: Array<{
  memberId: string
  account: AccountType
  amount: number
  reference?: string
  notes?: string
}>): Promise<Array<{ ok: boolean; error?: string }>> {
  return Promise.all(rows.map(r => postDeposit({
    memberId: r.memberId,
    memberName: '',
    accountType: r.account,
    amount: r.amount,
    method: 'cash',
    reference: r.reference,
    notes: r.notes,
  })))
}

export async function postRepayment(params: {
  memberId: string
  loanId: string
  loanNumber: string
  outstanding: number
  amount: number
  method: PaymentMethod
  reference?: string
}): Promise<{ ok: boolean; fullyRepaid?: boolean; error?: string }> {
  const { memberId, loanId, loanNumber, outstanding, amount, method, reference } = params
  const repayAmt = Math.min(amount, outstanding)
  const newOutstanding = +(outstanding - repayAmt).toFixed(2)
  const isFullyRepaid = newOutstanding <= 0

  try {
    const { error: lErr } = await admin.from('loans').update({
      outstanding_balance: newOutstanding,
      status: isFullyRepaid ? 'repaid' : 'disbursed',
      updated_at: new Date().toISOString(),
    }).eq('id', loanId)
    if (lErr) return { ok: false, error: lErr.message }

    const { error: tErr } = await admin.from('transactions').insert({
      member_id: memberId, account_type: 'bosa',
      transaction_type: 'loan_repayment',
      amount: repayAmt, balance_before: outstanding, balance_after: newOutstanding,
      reference: reference || `REP-${Date.now()}`,
      description: `Manual repayment (${method}) for ${loanNumber}`,
      status: 'completed', payment_method: method,
    })
    if (tErr) return { ok: false, error: tErr.message }

    await admin.from('notifications').insert({
      member_id: memberId, type: 'payment',
      title: isFullyRepaid ? 'Loan Fully Repaid 🎉' : 'Loan Repayment Posted ✅',
      body: isFullyRepaid
        ? `Your loan ${loanNumber} has been fully repaid. Congratulations!`
        : `KES ${repayAmt.toLocaleString()} repayment posted for loan ${loanNumber}. Outstanding: KES ${newOutstanding.toLocaleString()}.`,
      is_read: false,
    })

    return { ok: true, fullyRepaid: isFullyRepaid }
  } catch (e: any) {
    return { ok: false, error: e.message ?? 'Unknown error' }
  }
}
