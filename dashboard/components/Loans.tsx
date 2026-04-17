'use client'
import { useEffect, useState } from 'react'
import { supabase, callFunction } from '@/lib/supabase'
import LoanDetail from './LoanDetail'

export default function Loans() {
  const [loans, setLoans] = useState<any[]>([])
  const [filter, setFilter] = useState('pending')
  const [loading, setLoading] = useState(true)
  const [acting, setActing] = useState<string | null>(null)
  const [selected, setSelected] = useState<any>(null)
  const [counts, setCounts] = useState<Record<string, number>>({})

  useEffect(() => { loadCounts() }, [])
  useEffect(() => { load() }, [filter])

  async function loadCounts() {
    const statuses = ['pending', 'approved', 'disbursed', 'repaid', 'defaulted', 'rejected']
    const results = await Promise.all(
      statuses.map(s => supabase.from('loans').select('id', { count: 'exact', head: true }).eq('status', s))
    )
    const c: Record<string, number> = {}
    statuses.forEach((s, i) => { c[s] = results[i].count ?? 0 })
    setCounts(c)
  }

  async function load() {
    setLoading(true)
    const { data, error } = await supabase.from('loans')
      .select('id, loan_number, loan_type, principal, outstanding_balance, monthly_repayment, total_repayable, duration_months, interest_rate, purpose, status, created_at, due_date, disbursed_at, member_id')
      .eq('status', filter)
      .order('created_at', { ascending: false })
      .limit(100)
    if (error) console.error('[LOANS]', error)
    if (!data?.length) { setLoans([]); setLoading(false); return }

    // Fetch member details separately
    const memberIds = Array.from(new Set(data.map((l: any) => l.member_id).filter(Boolean)))
    const { data: members } = await supabase.from('members')
      .select('id, full_name, member_number, phone_number')
      .in('id', memberIds)
    const memberMap = Object.fromEntries((members ?? []).map((m: any) => [m.id, m]))
    setLoans(data.map((l: any) => ({ ...l, members: memberMap[l.member_id] ?? null })))
    setLoading(false)
  }

  async function approve(id: string, e: React.MouseEvent) {
    e.stopPropagation()
    setActing(id)
    await callFunction('loans', { action: 'approve', loan_id: id })
    await load(); await loadCounts()
    setActing(null)
  }

  async function disburse(id: string, e: React.MouseEvent) {
    e.stopPropagation()
    setActing(id)
    await callFunction('loans', { action: 'disburse', loan_id: id })
    await load(); await loadCounts()
    setActing(null)
  }

  const STATUS_TABS = ['pending', 'approved', 'disbursed', 'repaid', 'defaulted', 'rejected']

  return (
    <div>
      {selected && (
        <LoanDetail
          loan={selected}
          onClose={() => setSelected(null)}
          onRefresh={() => { load(); loadCounts() }}
        />
      )}

      <h2 className="text-xl font-semibold mb-4 text-gray-900 dark:text-gray-100">Loans</h2>
      <div className="flex gap-2 mb-5 flex-wrap">
        {STATUS_TABS.map(s => (
          <button key={s} onClick={() => setFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium capitalize transition-colors
              ${filter === s ? 'bg-green-600 text-white' : 'bg-white dark:bg-gray-900 border dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
            {s} {counts[s] !== undefined ? `(${counts[s]})` : ''}
          </button>
        ))}
      </div>

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500 dark:text-gray-400 text-xs uppercase">
              <tr>{['Loan #', 'Member', 'Type', 'Principal', 'Outstanding', 'Monthly', 'Date', 'Actions'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {loans.map(l => (
                <tr key={l.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/60 cursor-pointer" onClick={() => setSelected(l)}>
                  <td className="px-4 py-3 font-mono text-xs text-gray-500 dark:text-gray-400">{l.loan_number}</td>
                  <td className="px-4 py-3">
                    <p className="font-medium text-gray-900 dark:text-gray-100">{(l.members as any)?.full_name}</p>
                    <p className="text-xs text-gray-400">{(l.members as any)?.phone_number}</p>
                  </td>
                  <td className="px-4 py-3 capitalize text-gray-500 dark:text-gray-400 text-xs">{l.loan_type?.replace(/_/g, ' ')}</td>
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-gray-100">{fmt(l.principal)}</td>
                  <td className="px-4 py-3 text-gray-500 dark:text-gray-400">{fmt(l.outstanding_balance)}</td>
                  <td className="px-4 py-3 text-gray-500 dark:text-gray-400">{fmt(l.monthly_repayment)}</td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{l.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3 flex gap-2" onClick={e => e.stopPropagation()}>
                    {l.status === 'pending' && (
                      <button disabled={acting === l.id} onClick={e => approve(l.id, e)}
                        className="text-xs bg-green-600 text-white px-2 py-1 rounded hover:bg-green-700 disabled:opacity-50">
                        {acting === l.id ? '...' : 'Approve'}
                      </button>
                    )}
                    {l.status === 'approved' && (
                      <button disabled={acting === l.id} onClick={e => disburse(l.id, e)}
                        className="text-xs bg-blue-600 text-white px-2 py-1 rounded hover:bg-blue-700 disabled:opacity-50">
                        {acting === l.id ? '...' : 'Disburse'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {loans.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No {filter} loans</p>}
        </div>
      )}
    </div>
  )
}

function fmt(n: any) {
  return `KES ${parseFloat(n ?? 0).toLocaleString('en-KE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
