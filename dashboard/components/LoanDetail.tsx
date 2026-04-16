'use client'
import { useEffect, useState } from 'react'
import { supabase, callFunction } from '@/lib/supabase'

interface Props {
  loan: any
  onClose: () => void
  onRefresh: () => void
}

const STATUS_COLOR: Record<string, string> = {
  pending:   'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400',
  approved:  'bg-purple-100 dark:bg-purple-900/40 text-purple-700 dark:text-purple-400',
  disbursed: 'bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-400',
  repaid:    'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400',
  defaulted: 'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-400',
  rejected:  'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400',
}

export default function LoanDetail({ loan, onClose, onRefresh }: Props) {
  const [schedule, setSchedule] = useState<any[]>([])
  const [repayments, setRepayments] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [acting, setActing] = useState<string | null>(null)
  const [tab, setTab] = useState<'summary' | 'schedule' | 'repayments'>('summary')
  const [toast, setToast] = useState('')

  useEffect(() => {
    async function load() {
      const [schedRes, repRes] = await Promise.all([
        callFunction('loans', { action: 'schedule', loan_id: loan.id }),
        supabase.from('transactions')
          .select('id, amount, created_at, reference, status')
          .eq('member_id', loan.member_id ?? (loan.members as any)?.id)
          .eq('transaction_type', 'loan_repayment')
          .order('created_at', { ascending: false }),
      ])
      setSchedule(schedRes?.schedule ?? [])
      setRepayments(repRes.data ?? [])
      setLoading(false)
    }
    load()
  }, [loan.id])

  async function act(action: 'approve' | 'disburse' | 'reject') {
    setActing(action)
    if (action === 'reject') {
      await supabase.from('loans').update({ status: 'rejected' }).eq('id', loan.id)
    } else {
      await callFunction('loans', { action, loan_id: loan.id })
    }
    showToast(`Loan ${action}d`)
    onRefresh()
    setActing(null)
    onClose()
  }

  function showToast(msg: string) {
    setToast(msg)
    setTimeout(() => setToast(''), 2500)
  }

  const member = loan.members as any
  const paidAmount = parseFloat(loan.principal ?? 0) - parseFloat(loan.outstanding_balance ?? 0)
  const progressPct = loan.principal > 0
    ? Math.min(100, (paidAmount / parseFloat(loan.principal)) * 100)
    : 0

  return (
    <div className="fixed inset-0 bg-black/40 dark:bg-black/60 z-50 flex items-start justify-end" onClick={onClose}>
      <div className="bg-white dark:bg-gray-900 h-full w-full max-w-2xl shadow-2xl overflow-y-auto"
        onClick={e => e.stopPropagation()}>

        {toast && (
          <div className="fixed top-4 right-4 bg-green-600 text-white text-sm px-4 py-2 rounded-lg shadow z-50">
            {toast}
          </div>
        )}

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b dark:border-gray-800 sticky top-0 bg-white dark:bg-gray-900 z-10">
          <div>
            <div className="flex items-center gap-2">
              <h2 className="font-semibold text-lg font-mono text-gray-900 dark:text-gray-100">{loan.loan_number}</h2>
              <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_COLOR[loan.status] ?? 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400'}`}>
                {loan.status}
              </span>
            </div>
            <p className="text-xs text-gray-400 mt-0.5 capitalize">{loan.loan_type?.replace(/_/g, ' ')} · {member?.full_name}</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 text-xl leading-none">✕</button>
        </div>

        <div className="p-6">
          {/* Action buttons */}
          {loan.status === 'pending' && (
            <div className="flex gap-2 mb-5">
              <button disabled={!!acting} onClick={() => act('approve')}
                className="flex-1 bg-green-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-green-700 disabled:opacity-50">
                {acting === 'approve' ? 'Approving...' : 'Approve Loan'}
              </button>
              <button disabled={!!acting} onClick={() => act('reject')}
                className="flex-1 bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-400 rounded-lg py-2 text-sm font-medium hover:bg-red-200 dark:hover:bg-red-900/60 disabled:opacity-50">
                {acting === 'reject' ? 'Rejecting...' : 'Reject'}
              </button>
            </div>
          )}
          {loan.status === 'approved' && (
            <div className="mb-5">
              <button disabled={!!acting} onClick={() => act('disburse')}
                className="w-full bg-blue-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-blue-700 disabled:opacity-50">
                {acting === 'disburse' ? 'Disbursing...' : 'Disburse to FOSA'}
              </button>
            </div>
          )}

            <div className="flex gap-1 mb-5 border-b dark:border-gray-800">
            {(['summary', 'schedule', 'repayments'] as const).map(t => (
              <button key={t} onClick={() => setTab(t)}
                className={`px-4 py-2 text-sm font-medium capitalize border-b-2 transition-colors -mb-px
                  ${tab === t ? 'border-green-600 text-green-700 dark:text-green-400' : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}`}>
                {t}
              </button>
            ))}
          </div>

          {/* Summary tab */}
          {tab === 'summary' && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                {[
                  { label: 'Principal',       value: fmt(loan.principal) },
                  { label: 'Outstanding',     value: fmt(loan.outstanding_balance) },
                  { label: 'Monthly',         value: fmt(loan.monthly_repayment) },
                  { label: 'Total Repayable', value: fmt(loan.total_repayable) },
                  { label: 'Duration',        value: `${loan.duration_months} months` },
                  { label: 'Interest Rate',   value: `${loan.interest_rate ?? 0}% p.a.` },
                  { label: 'Applied',         value: loan.created_at?.split('T')[0] },
                  { label: 'Due Date',        value: loan.due_date ?? '—' },
                ].map(r => (
                  <div key={r.label} className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
                    <p className="text-xs text-gray-400">{r.label}</p>
                    <p className="font-medium text-sm mt-0.5 text-gray-900 dark:text-gray-100">{r.value}</p>
                  </div>
                ))}
              </div>

              {['disbursed', 'repaid'].includes(loan.status) && (
                <div className="bg-white dark:bg-gray-800 border dark:border-gray-700 rounded-xl p-4">
                  <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400 mb-2">
                    <span>Repayment Progress</span>
                    <span>{progressPct.toFixed(1)}%</span>
                  </div>
                  <div className="h-2 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
                    <div className="h-full bg-green-500 rounded-full transition-all"
                      style={{ width: `${progressPct}%` }} />
                  </div>
                  <div className="flex justify-between text-xs mt-2">
                    <span className="text-green-600 dark:text-green-400">Paid: {fmt(paidAmount)}</span>
                    <span className="text-gray-400">Remaining: {fmt(loan.outstanding_balance)}</span>
                  </div>
                </div>
              )}

              {loan.purpose && (
                <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
                  <p className="text-xs text-gray-400 mb-1">Purpose</p>
                  <p className="text-sm text-gray-900 dark:text-gray-100">{loan.purpose}</p>
                </div>
              )}
            </div>
          )}

          {/* Schedule tab */}
          {tab === 'schedule' && (
            loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
              schedule.length === 0
                ? <p className="text-gray-400 text-sm">No schedule available</p>
                : (
                  <div className="overflow-auto max-h-[60vh]">
                    <table className="w-full text-xs">
                      <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500 dark:text-gray-400 uppercase sticky top-0">
                        <tr>{['Month', 'Payment', 'Principal', 'Interest', 'Balance'].map(h => (
                          <th key={h} className="px-3 py-2 text-left">{h}</th>
                        ))}</tr>
                      </thead>
                      <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                        {schedule.map((row: any) => (
                          <tr key={row.month} className="hover:bg-gray-50 dark:hover:bg-gray-800/60">
                            <td className="px-3 py-2 font-medium text-gray-900 dark:text-gray-100">{row.month}</td>
                            <td className="px-3 py-2 text-gray-900 dark:text-gray-100">{fmt(row.payment)}</td>
                            <td className="px-3 py-2 text-blue-600 dark:text-blue-400">{fmt(row.principal)}</td>
                            <td className="px-3 py-2 text-orange-500 dark:text-orange-400">{fmt(row.interest)}</td>
                            <td className="px-3 py-2 text-gray-500 dark:text-gray-400">{fmt(row.balance)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )
            )
          )}

          {/* Repayments tab */}
          {tab === 'repayments' && (
            repayments.length === 0
              ? <p className="text-gray-400 text-sm">No repayments recorded</p>
              : (
                <div className="space-y-2">
                  {repayments.map(r => (
                    <div key={r.id} className="flex items-center justify-between border dark:border-gray-700 rounded-lg px-4 py-3">
                      <div>
                        <p className="text-sm font-medium text-gray-900 dark:text-gray-100">{fmt(r.amount)}</p>
                        <p className="text-xs text-gray-400">{r.created_at?.split('T')[0]} · {r.reference}</p>
                      </div>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                        r.status === 'completed' ? 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400' : 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400'}`}>
                        {r.status}
                      </span>
                    </div>
                  ))}
                </div>
              )
          )}
        </div>
      </div>
    </div>
  )
}

function fmt(n: any) {
  return `KES ${parseFloat(n ?? 0).toLocaleString('en-KE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
