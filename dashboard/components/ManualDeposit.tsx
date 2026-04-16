'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { postDeposit } from '@/app/actions/deposit'

type AccountType = 'fosa' | 'bosa_savings' | 'bosa_shares'
type PaymentMethod = 'cash' | 'cheque' | 'bank_transfer' | 'mpesa'

const ACCOUNT_LABELS: Record<AccountType, string> = {
  fosa: 'FOSA (Current Account)',
  bosa_savings: 'BOSA Savings',
  bosa_shares: 'BOSA Shares',
}

export default function ManualDeposit() {
  const [members, setMembers] = useState<any[]>([])
  const [search, setSearch] = useState('')
  const [selectedMember, setSelectedMember] = useState<any>(null)
  const [accountType, setAccountType] = useState<AccountType>('fosa')
  const [amount, setAmount] = useState('')
  const [method, setMethod] = useState<PaymentMethod>('cash')
  const [reference, setReference] = useState('')
  const [notes, setNotes] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null)
  const [history, setHistory] = useState<any[]>([])
  const [loadingHistory, setLoadingHistory] = useState(true)

  useEffect(() => {
    supabase.from('members').select('id, full_name, member_number, phone_number, status')
      .eq('status', 'active').order('full_name').limit(300)
      .then(({ data }) => setMembers(data ?? []))
    loadHistory()
  }, [])

  async function loadHistory() {
    setLoadingHistory(true)
    const { data } = await supabase
      .from('transactions')
      .select('id, amount, transaction_type, reference, description, created_at, members!transactions_member_id_fkey(full_name, member_number)')
      .in('transaction_type', ['deposit', 'share_purchase'])
      .order('created_at', { ascending: false })
      .limit(30)
    setHistory(data ?? [])
    setLoadingHistory(false)
  }

  const filtered = members.filter(m =>
    m.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    m.member_number?.includes(search) ||
    m.phone_number?.includes(search)
  )

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    if (!selectedMember || !amount || parseFloat(amount) <= 0) return
    setSubmitting(true)

    const result = await postDeposit({
      memberId: selectedMember.id,
      memberName: selectedMember.full_name,
      accountType,
      amount: parseFloat(amount),
      method,
      reference: reference || undefined,
      notes: notes || undefined,
    })

    if (result.ok) {
      showToast(`KES ${parseFloat(amount).toLocaleString()} deposited to ${selectedMember.full_name}`, true)
      setAmount(''); setReference(''); setNotes('')
      setSelectedMember(null); setSearch('')
      loadHistory()
    } else {
      showToast(result.error ?? 'Deposit failed', false)
    }
    setSubmitting(false)
  }

  function showToast(msg: string, ok: boolean) {
    setToast({ msg, ok })
    setTimeout(() => setToast(null), 3500)
  }

  return (
    <div>
      <h2 className="text-xl font-semibold mb-5">Manual Deposit</h2>

      {toast && (
        <div className={`fixed top-4 right-4 text-white text-sm px-4 py-2 rounded-lg shadow z-50 ${toast.ok ? 'bg-green-600' : 'bg-red-600'}`}>
          {toast.msg}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Form */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
          <h3 className="font-medium text-gray-700 mb-4">Deposit Details</h3>
          <form onSubmit={submit} className="flex flex-col gap-3">

            {/* Member search */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Member</label>
              {selectedMember ? (
                <div className="flex items-center justify-between border rounded-lg px-3 py-2 bg-green-50 border-green-200">
                  <div>
                    <p className="text-sm font-medium">{selectedMember.full_name}</p>
                    <p className="text-xs text-gray-400">{selectedMember.member_number} · {selectedMember.phone_number}</p>
                  </div>
                  <button type="button" onClick={() => { setSelectedMember(null); setSearch('') }}
                    className="text-gray-400 hover:text-gray-600 text-sm">✕</button>
                </div>
              ) : (
                <div className="relative">
                  <input placeholder="Search member..." value={search} onChange={e => setSearch(e.target.value)}
                    className="border rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-green-500" />
                  {search && filtered.length > 0 && (
                    <div className="absolute z-10 w-full bg-white border rounded-lg shadow-lg mt-1 max-h-48 overflow-y-auto">
                      {filtered.slice(0, 8).map(m => (
                        <button key={m.id} type="button"
                          onClick={() => { setSelectedMember(m); setSearch('') }}
                          className="w-full text-left px-3 py-2 hover:bg-gray-50 text-sm border-b last:border-0">
                          <p className="font-medium">{m.full_name}</p>
                          <p className="text-xs text-gray-400">{m.member_number}</p>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Account type */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Account</label>
              <div className="grid grid-cols-3 gap-2">
                {(Object.entries(ACCOUNT_LABELS) as [AccountType, string][]).map(([k, v]) => (
                  <button key={k} type="button" onClick={() => setAccountType(k)}
                    className={`py-2 px-2 rounded-lg text-xs font-medium border transition-colors text-center
                      ${accountType === k ? 'bg-green-600 text-white border-green-600' : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'}`}>
                    {v}
                  </button>
                ))}
              </div>
            </div>

            {/* Amount */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Amount (KES)</label>
              <input type="number" min="1" required placeholder="0.00" value={amount}
                onChange={e => setAmount(e.target.value)}
                className="border rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>

            {/* Payment method */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Payment Method</label>
              <div className="flex gap-2 flex-wrap">
                {(['cash', 'cheque', 'bank_transfer', 'mpesa'] as PaymentMethod[]).map(m => (
                  <button key={m} type="button" onClick={() => setMethod(m)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium capitalize border transition-colors
                      ${method === m ? 'bg-green-600 text-white border-green-600' : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'}`}>
                    {m.replace('_', ' ')}
                  </button>
                ))}
              </div>
            </div>

            {/* Reference */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Reference (optional)</label>
              <input placeholder="Cheque no., M-Pesa code..." value={reference}
                onChange={e => setReference(e.target.value)}
                className="border rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>

            {/* Notes */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Notes (optional)</label>
              <input placeholder="e.g. Monthly contribution" value={notes}
                onChange={e => setNotes(e.target.value)}
                className="border rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>

            <button type="submit" disabled={submitting || !selectedMember || !amount}
              className="bg-green-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-green-700 disabled:opacity-50 mt-1">
              {submitting ? 'Processing...' : 'Post Deposit'}
            </button>
          </form>
        </div>

        {/* Recent deposits */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
          <h3 className="font-medium text-gray-700 mb-4">Recent Deposits</h3>
          {loadingHistory ? <p className="text-gray-400 text-sm">Loading...</p> : (
            <div className="space-y-2 max-h-[520px] overflow-y-auto pr-1">
              {history.length === 0 && <p className="text-gray-400 text-sm">No deposits yet</p>}
              {history.map(h => (
                <div key={h.id} className="flex items-center justify-between border rounded-lg px-3 py-2.5">
                  <div className="min-w-0">
                    <p className="text-sm font-medium truncate">{(h.members as any)?.full_name}</p>
                    <p className="text-xs text-gray-400">{h.created_at?.split('T')[0]} · {h.reference}</p>
                    {h.description && <p className="text-xs text-gray-400 truncate">{h.description}</p>}
                  </div>
                  <p className="text-sm font-semibold text-green-600 ml-3 shrink-0">
                    +KES {parseFloat(h.amount).toLocaleString('en-KE', { maximumFractionDigits: 0 })}
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
