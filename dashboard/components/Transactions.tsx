'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

const TYPES = ['', 'deposit', 'withdrawal', 'loan_disbursement', 'loan_repayment', 'transfer', 'dividend']

const CREDIT_TYPES = new Set(['deposit', 'loan_disbursement', 'dividend', 'share_purchase'])

export default function Transactions() {
  const [txs, setTxs] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [type, setType] = useState('')
  const [search, setSearch] = useState('')
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')

  useEffect(() => { load() }, [type, startDate, endDate])

  async function load() {
    setLoading(true)
    let q = supabase.from('transactions')
      .select('id, transaction_type, amount, status, reference, created_at, members(full_name, member_number)')
      .order('created_at', { ascending: false })
      .limit(200)
    if (type) q = q.eq('transaction_type', type)
    if (startDate) q = q.gte('created_at', startDate)
    if (endDate)   q = q.lte('created_at', endDate + 'T23:59:59')
    const { data } = await q
    setTxs(data ?? [])
    setLoading(false)
  }

  function exportCsv() {
    const cols = ['date', 'member', 'type', 'amount', 'reference', 'status']
    const rows = filtered.map(t => [
      t.created_at?.split('T')[0],
      (t.members as any)?.full_name ?? '',
      t.transaction_type,
      parseFloat(t.amount).toFixed(2),
      t.reference,
      t.status,
    ])
    const csv = [cols, ...rows].map(r => r.join(',')).join('\n')
    const a = document.createElement('a')
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
    a.download = `transactions_${Date.now()}.csv`
    a.click()
  }

  const filtered = txs.filter(t => {
    if (!search) return true
    const name = (t.members as any)?.full_name?.toLowerCase() ?? ''
    return name.includes(search.toLowerCase()) || t.reference?.includes(search)
  })

  // Daily totals summary
  const totalIn  = filtered.filter(t => CREDIT_TYPES.has(t.transaction_type) && t.status === 'completed')
    .reduce((s, t) => s + parseFloat(t.amount), 0)
  const totalOut = filtered.filter(t => !CREDIT_TYPES.has(t.transaction_type) && t.status === 'completed')
    .reduce((s, t) => s + parseFloat(t.amount), 0)
  const pending  = filtered.filter(t => t.status === 'pending').length

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold">Transactions</h2>
        <button onClick={exportCsv}
          className="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50 flex items-center gap-1">
          ⬇ Export CSV
        </button>
      </div>

      {/* Filters */}
      <div className="flex gap-2 mb-4 flex-wrap">
        <select value={type} onChange={e => setType(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          {TYPES.map(t => <option key={t} value={t}>{t || 'All types'}</option>)}
        </select>
        <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
        <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
        <input placeholder="Search member or ref..." value={search} onChange={e => setSearch(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm w-52 focus:outline-none focus:ring-2 focus:ring-green-500" />
        {(type || startDate || endDate || search) && (
          <button onClick={() => { setType(''); setStartDate(''); setEndDate(''); setSearch('') }}
            className="text-xs text-gray-400 hover:text-gray-600 px-2">Clear</button>
        )}
      </div>

      {/* Summary bar */}
      {!loading && filtered.length > 0 && (
        <div className="grid grid-cols-3 gap-3 mb-4">
          <div className="bg-green-50 border border-green-100 rounded-lg px-4 py-2.5">
            <p className="text-xs text-gray-500">Total In</p>
            <p className="font-bold text-green-700">{fmt(totalIn)}</p>
          </div>
          <div className="bg-red-50 border border-red-100 rounded-lg px-4 py-2.5">
            <p className="text-xs text-gray-500">Total Out</p>
            <p className="font-bold text-red-600">{fmt(totalOut)}</p>
          </div>
          <div className="bg-yellow-50 border border-yellow-100 rounded-lg px-4 py-2.5">
            <p className="text-xs text-gray-500">Pending</p>
            <p className="font-bold text-yellow-700">{pending}</p>
          </div>
        </div>
      )}

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>{['Date', 'Member', 'Type', 'Amount', 'Reference', 'Status'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filtered.map(t => (
                <tr key={t.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-400 text-xs">{t.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3 font-medium">{(t.members as any)?.full_name ?? '—'}</td>
                  <td className="px-4 py-3 text-xs capitalize text-gray-500">{t.transaction_type?.replace(/_/g, ' ')}</td>
                  <td className={`px-4 py-3 font-medium ${CREDIT_TYPES.has(t.transaction_type) ? 'text-green-600' : 'text-red-500'}`}>
                    {CREDIT_TYPES.has(t.transaction_type) ? '+' : '-'}{fmt(t.amount)}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-400">{t.reference}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      t.status === 'completed' ? 'bg-green-100 text-green-700' :
                      t.status === 'pending'   ? 'bg-yellow-100 text-yellow-700' :
                      'bg-red-100 text-red-700'}`}>{t.status}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No transactions</p>}
        </div>
      )}
    </div>
  )
}

function fmt(n: any) {
  return `KES ${parseFloat(n ?? 0).toLocaleString('en-KE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
