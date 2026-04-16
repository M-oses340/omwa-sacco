'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { postRepayment } from '@/app/actions/deposit'

type PaymentMethod = 'cash' | 'cheque' | 'bank_transfer' | 'mpesa'

export default function RepaymentPosting() {
  const [members, setMembers] = useState<any[]>([])
  const [search, setSearch] = useState('')
  const [selectedMember, setSelectedMember] = useState<any>(null)
  const [activeLoan, setActiveLoan] = useState<any>(null)
  const [loadingLoan, setLoadingLoan] = useState(false)
  const [amount, setAmount] = useState('')
  const [method, setMethod] = useState<PaymentMethod>('cash')
  const [reference, setReference] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null)
  const [history, setHistory] = useState<any[]>([])
  const [loadingHistory, setLoadingHistory] = useState(true)

  useEffect(() => {
    supabase.from('members').select('id, full_name, member_number, phone_number')
      .eq('status', 'active').order('full_name').limit(300)
      .then(({ data }) => setMembers(data ?? []))
    loadHistory()
  }, [])

  useEffect(() => {
    if (selectedMember) loadActiveLoan(selectedMember.id)
    else setActiveLoan(null)
  }, [selectedMember])

  async function loadActiveLoan(memberId: string) {
    setLoadingLoan(true)
    const { data } = await supabase
      .from('loans')
      .select('id, loan_number, loan_type, principal, outstanding_balance, monthly_repayment, due_date')
      .eq('member_id', memberId)
      .eq('status', 'disbursed')
      .maybeSingle()
    setActiveLoan(data)
    if (data) setAmount(parseFloat(data.monthly_repayment).toFixed(2))
    setLoadingLoan(false)
  }

  async function loadHistory() {
    setLoadingHistory(true)
    const { data } = await supabase
      .from('transactions')
      .select('id, amount, reference, description, created_at, members!transactions_member_id_fkey(full_name, member_number)')
      .eq('transaction_type', 'loan_repayment')
      .order('created_at', { ascending: false })
      .limit(30)
    setHistory(data ?? [])
    setLoadingHistory(false)
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    if (!selectedMember || !activeLoan || !amount) return
    const amt = parseFloat(amount)
    if (amt <= 0) return
    setSubmitting(true)

    const result = await postRepayment({
      memberId: selectedMember.id,
      loanId: activeLoan.id,
      loanNumber: activeLoan.loan_number,
      outstanding: parseFloat(activeLoan.outstanding_balance),
      amount: amt,
      method,
      reference: reference || undefined,
    })

    if (result.ok) {
      showToast(`KES ${amt.toLocaleString()} posted${result.fullyRepaid ? ' — loan fully repaid!' : ''}`, true)
      setAmount(''); setReference('')
      setSelectedMember(null); setSearch(''); setActiveLoan(null)
      loadHistory()
    } else {
      showToast(result.error ?? 'Failed to post repayment', false)
    }
    setSubmitting(false)
  }

  function showToast(msg: string, ok: boolean) {
    setToast({ msg, ok })
    setTimeout(() => setToast(null), 4000)
  }

  const filtered = members.filter(m =>
    m.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    m.member_number?.includes(search) ||
    m.phone_number?.includes(search)
  )

  const outstanding = activeLoan ? parseFloat(activeLoan.outstanding_balance) : 0
  const monthly     = activeLoan ? parseFloat(activeLoan.monthly_repayment) : 0
  const paidPct     = activeLoan
    ? Math.min(100, ((parseFloat(activeLoan.principal) - outstanding) / parseFloat(activeLoan.principal)) * 100)
    : 0

  return (
    <div>
      <h2 className="text-xl font-semibold mb-1 text-gray-900 dark:text-gray-100">Loan Repayment Posting</h2>
      <p className="text-gray-500 dark:text-gray-400 text-sm mb-5">Post cash or cheque repayments received at the office.</p>

      {toast && (
        <div className={`fixed top-4 right-4 text-white text-sm px-4 py-2 rounded-lg shadow z-50 ${toast.ok ? 'bg-green-600' : 'bg-red-600'}`}>
          {toast.msg}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Form */}
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 p-5">
          <h3 className="font-medium text-gray-700 dark:text-gray-300 mb-4">Post Repayment</h3>
          <form onSubmit={submit} className="flex flex-col gap-3">
            <div>
              <label className="text-xs text-gray-500 dark:text-gray-400 mb-1 block">Member</label>
              {selectedMember ? (
                <div className="flex items-center justify-between border dark:border-gray-700 rounded-lg px-3 py-2 bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800">
                  <div>
                    <p className="text-sm font-medium text-gray-900 dark:text-gray-100">{selectedMember.full_name}</p>
                    <p className="text-xs text-gray-400">{selectedMember.member_number} · {selectedMember.phone_number}</p>
                  </div>
                  <button type="button" onClick={() => { setSelectedMember(null); setSearch(''); setActiveLoan(null) }}
                    className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 text-sm">✕</button>
                </div>
              ) : (
                <div className="relative">
                  <input placeholder="Search member..." value={search} onChange={e => setSearch(e.target.value)}
                    className="border dark:border-gray-700 rounded-lg px-3 py-2 text-sm w-full bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500" />
                  {search && filtered.length > 0 && (
                    <div className="absolute z-10 w-full bg-white dark:bg-gray-800 border dark:border-gray-700 rounded-lg shadow-lg mt-1 max-h-48 overflow-y-auto">
                      {filtered.slice(0, 8).map(m => (
                        <button key={m.id} type="button"
                          onClick={() => { setSelectedMember(m); setSearch('') }}
                          className="w-full text-left px-3 py-2 hover:bg-gray-50 dark:hover:bg-gray-700 text-sm border-b dark:border-gray-700 last:border-0">
                          <p className="font-medium text-gray-900 dark:text-gray-100">{m.full_name}</p>
                          <p className="text-xs text-gray-400">{m.member_number}</p>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>

            {selectedMember && (
              <div className={`rounded-lg p-3 text-sm border ${
                loadingLoan ? 'bg-gray-50 dark:bg-gray-800 border-gray-100 dark:border-gray-700' :
                activeLoan  ? 'bg-blue-50 dark:bg-blue-900/20 border-blue-100 dark:border-blue-800' :
                'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-100 dark:border-yellow-800'}`}>
                {loadingLoan && <p className="text-gray-400 text-xs">Loading loan...</p>}
                {!loadingLoan && !activeLoan && (
                  <p className="text-yellow-700 dark:text-yellow-400 text-xs">No active disbursed loan found for this member.</p>
                )}
                {!loadingLoan && activeLoan && (
                  <>
                    <div className="flex justify-between mb-2">
                      <span className="font-medium font-mono text-xs text-gray-900 dark:text-gray-100">{activeLoan.loan_number}</span>
                      <span className="text-xs capitalize text-blue-600 dark:text-blue-400">{activeLoan.loan_type?.replace(/_/g, ' ')}</span>
                    </div>
                    <div className="grid grid-cols-2 gap-2 text-xs mb-2">
                      <div><p className="text-gray-400">Outstanding</p><p className="font-semibold text-red-600 dark:text-red-400">KES {outstanding.toLocaleString('en-KE', { maximumFractionDigits: 0 })}</p></div>
                      <div><p className="text-gray-400">Monthly</p><p className="font-semibold text-gray-900 dark:text-gray-100">KES {monthly.toLocaleString('en-KE', { maximumFractionDigits: 0 })}</p></div>
                    </div>
                    <div className="h-1.5 bg-blue-100 dark:bg-blue-900/40 rounded-full overflow-hidden">
                      <div className="h-full bg-blue-500 rounded-full" style={{ width: `${paidPct}%` }} />
                    </div>
                    <p className="text-xs text-gray-400 mt-1">{paidPct.toFixed(1)}% repaid · Due {activeLoan.due_date}</p>
                  </>
                )}
              </div>
            )}

            <div>
              <label className="text-xs text-gray-500 dark:text-gray-400 mb-1 block">Amount (KES)</label>
              <input type="number" min="1" required placeholder="0.00" value={amount} onChange={e => setAmount(e.target.value)}
                className="border dark:border-gray-700 rounded-lg px-3 py-2 text-sm w-full bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500" />
              {activeLoan && parseFloat(amount) > outstanding && (
                <p className="text-xs text-orange-500 mt-1">Amount exceeds outstanding — will be capped at KES {outstanding.toLocaleString()}</p>
              )}
            </div>

            <div>
              <label className="text-xs text-gray-500 dark:text-gray-400 mb-1 block">Payment Method</label>
              <div className="flex gap-2 flex-wrap">
                {(['cash', 'cheque', 'bank_transfer', 'mpesa'] as PaymentMethod[]).map(m => (
                  <button key={m} type="button" onClick={() => setMethod(m)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium capitalize border transition-colors
                      ${method === m ? 'bg-green-600 text-white border-green-600' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700'}`}>
                    {m.replace('_', ' ')}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="text-xs text-gray-500 dark:text-gray-400 mb-1 block">Reference (optional)</label>
              <input placeholder="Cheque no., receipt no..." value={reference} onChange={e => setReference(e.target.value)}
                className="border dark:border-gray-700 rounded-lg px-3 py-2 text-sm w-full bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>

            <button type="submit" disabled={submitting || !selectedMember || !activeLoan || !amount}
              className="bg-green-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-green-700 disabled:opacity-50 mt-1">
              {submitting ? 'Posting...' : 'Post Repayment'}
            </button>
          </form>
        </div>

        {/* Recent repayments */}
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 p-5">
          <h3 className="font-medium text-gray-700 dark:text-gray-300 mb-4">Recent Repayments</h3>
          {loadingHistory ? <p className="text-gray-400 text-sm">Loading...</p> : (
            <div className="space-y-2 max-h-[520px] overflow-y-auto pr-1">
              {history.length === 0 && <p className="text-gray-400 text-sm">No repayments yet</p>}
              {history.map(h => (
                <div key={h.id} className="flex items-center justify-between border dark:border-gray-700 rounded-lg px-3 py-2.5">
                  <div className="min-w-0">
                    <p className="text-sm font-medium truncate text-gray-900 dark:text-gray-100">{(h.members as any)?.full_name}</p>
                    <p className="text-xs text-gray-400">{h.created_at?.split('T')[0]} · {h.reference}</p>
                    {h.description && <p className="text-xs text-gray-400 truncate">{h.description}</p>}
                  </div>
                  <p className="text-sm font-semibold text-blue-600 dark:text-blue-400 ml-3 shrink-0">
                    KES {parseFloat(h.amount).toLocaleString('en-KE', { maximumFractionDigits: 0 })}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
