'use client'
import { useEffect, useState } from 'react'
import { supabase, callFunction } from '@/lib/supabase'

export default function Loans() {
  const [loans, setLoans] = useState<any[]>([])
  const [filter, setFilter] = useState('pending')
  const [loading, setLoading] = useState(true)
  const [acting, setActing] = useState<string | null>(null)

  useEffect(() => { load() }, [filter])

  async function load() {
    setLoading(true)
    const { data } = await supabase.from('loans')
      .select('id, loan_number, loan_type, principal, outstanding_balance, monthly_repayment, status, created_at, due_date, members(full_name, member_number, phone_number)')
      .eq('status', filter)
      .order('created_at', { ascending: false })
      .limit(100)
    setLoans(data ?? [])
    setLoading(false)
  }

  async function approve(id: string) {
    setActing(id)
    await callFunction('loans', { action: 'approve', loan_id: id })
    await load()
    setActing(null)
  }

  async function disburse(id: string) {
    setActing(id)
    await callFunction('loans', { action: 'disburse', loan_id: id })
    await load()
    setActing(null)
  }

  const STATUS_TABS = ['pending', 'approved', 'disbursed', 'repaid', 'defaulted']

  return (
    <div>
      <h2 className="text-xl font-semibold mb-4">Loans</h2>
      <div className="flex gap-2 mb-5">
        {STATUS_TABS.map(s => (
          <button key={s} onClick={() => setFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium capitalize transition-colors
              ${filter === s ? 'bg-green-600 text-white' : 'bg-white border text-gray-600 hover:bg-gray-50'}`}>
            {s}
          </button>
        ))}
      </div>
      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>{['Loan #', 'Member', 'Type', 'Principal', 'Outstanding', 'Monthly', 'Date', 'Actions'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {loans.map(l => (
                <tr key={l.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs">{l.loan_number}</td>
                  <td className="px-4 py-3">
                    <p className="font-medium">{(l.members as any)?.full_name}</p>
                    <p className="text-xs text-gray-400">{(l.members as any)?.phone_number}</p>
                  </td>
                  <td className="px-4 py-3 capitalize text-gray-500 text-xs">{l.loan_type?.replace(/_/g, ' ')}</td>
                  <td className="px-4 py-3 font-medium">{fmt(l.principal)}</td>
                  <td className="px-4 py-3 text-gray-500">{fmt(l.outstanding_balance)}</td>
                  <td className="px-4 py-3 text-gray-500">{fmt(l.monthly_repayment)}</td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{l.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3 flex gap-2">
                    {l.status === 'pending' && (
                      <button disabled={acting === l.id} onClick={() => approve(l.id)}
                        className="text-xs bg-green-600 text-white px-2 py-1 rounded hover:bg-green-700 disabled:opacity-50">
                        {acting === l.id ? '...' : 'Approve'}
                      </button>
                    )}
                    {l.status === 'approved' && (
                      <button disabled={acting === l.id} onClick={() => disburse(l.id)}
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
