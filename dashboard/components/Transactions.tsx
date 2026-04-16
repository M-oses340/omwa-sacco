'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

const TYPES = ['', 'deposit', 'withdrawal', 'loan_disbursement', 'loan_repayment', 'transfer', 'dividend', 'share_purchase', 'scheduled_payment', 'paybill', 'airtime']
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
      .select('id, transaction_type, amount, status, reference, created_at, members!transactions_member_id_fkey(full_name, member_number)')
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

  const totalIn  = filtered.filter(t => CREDIT_TYPES.has(t.transaction_type) && t.status === 'completed').reduce((s, t) => s + parseFloat(t.amount), 0)
  const totalOut = filtered.filter(t => !CREDIT_TYPES.has(t.transaction_type) && t.status === 'completed').reduce((s, t) => s + parseFloat(t.amount), 0)
  const pending  = filtered.filter(t => t.status === 'pending').length

  const ctrl = 'border dark:border-gray-700 rounded-lg px-3 py-1.5 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500'

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Transactions</h2>
        <div className="flex gap-2">
          <button onClick={load} className="text-xs border dark:border-gray-700 rounded-lg px-3 py-1.5 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800">↻ Refresh</button>
          <button onClick={exportCsv} className="text-xs border dark:border-gray-700 rounded-lg px-3 py-1.5 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800">⬇ Export CSV</button>
        </div>
      </div>

      <div className="flex gap-2 mb-4 flex-wrap">
        <select value={type} onChange={e => setType(e.target.value)} className={ctrl}>
          {TYPES.map(t => <option key={t} value={t}>{t || 'All types'}</option>)}
        </select>
        <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className={ctrl} />
        <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className={ctrl} />
        <input placeholder="Search member or ref..." value={search} onChange={e => setSearch(e.target.value)} className={`${ctrl} w-52`} />
        {(type || startDate || endDate || search) && (
          <button onClick={() => { setType(''); setStartDate(''); setEndDate(''); setSearch('') }}
            className="text-xs text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 px-2">Clear</button>
        )}
      </div>

      {!loading && filtered.length > 0 && (
        <div className="grid grid-cols-3 gap-3 mb-4">
          <div className="bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-800 rounded-lg px-4 py-2.5">
            <p className="text-xs text-gray-500 dark:text-gray-400">Total In</p>
            <p className="font-bold text-green-700 dark:text-green-400">{fmt(totalIn)}</p>
          </div>
          <div className="bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-800 rounded-lg px-4 py-2.5">
            <p className="text-xs text-gray-500 dark:text-gray-400">Total Out</p>
            <p className="font-bold text-red-600 dark:text-red-400">{fmt(totalOut)}</p>
          </div>
          <div className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-100 dark:border-yellow-800 rounded-lg px-4 py-2.5">
            <p className="text-xs text-gray-500 dark:text-gray-400">Pending</p>
            <p className="font-bold text-yellow-700 dark:text-yellow-400">{pending}</p>
          </div>
        </div>
      )}

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500 dark:text-gray-400 text-xs uppercase">
              <tr>{['Date', 'Member', 'Type', 'Amount', 'Reference', 'Status'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {filtered.map(t => (
                <tr key={t.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/60">
                  <td className="px-4 py-3 text-gray-400 text-xs">{t.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-gray-100">{(t.members as any)?.full_name ?? '—'}</td>
                  <td className="px-4 py-3 text-xs capitalize text-gray-500 dark:text-gray-400">{t.transaction_type?.replace(/_/g, ' ')}</td>
                  <td className={`px-4 py-3 font-medium ${CREDIT_TYPES.has(t.transaction_type) ? 'text-green-600 dark:text-green-400' : 'text-red-500 dark:text-red-400'}`}>
                    {CREDIT_TYPES.has(t.transaction_type) ? '+' : '-'}{fmt(t.amount)}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-400">{t.reference}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      t.status === 'completed' ? 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400' :
                      t.status === 'pending'   ? 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400' :
                      'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-400'}`}>{t.status}</span>
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
