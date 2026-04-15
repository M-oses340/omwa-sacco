'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Transactions() {
  const [txs, setTxs] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [type, setType] = useState('')

  useEffect(() => { load() }, [type])

  async function load() {
    setLoading(true)
    let q = supabase.from('transactions')
      .select('id, transaction_type, amount, status, reference, created_at, members(full_name, member_number)')
      .order('created_at', { ascending: false })
      .limit(100)
    if (type) q = q.eq('transaction_type', type)
    const { data } = await q
    setTxs(data ?? [])
    setLoading(false)
  }

  const TYPES = ['', 'deposit', 'withdrawal', 'loan_disbursement', 'loan_repayment', 'transfer', 'dividend']

  return (
    <div>
      <div className="flex items-center justify-between mb-5">
        <h2 className="text-xl font-semibold">Transactions</h2>
        <select value={type} onChange={e => setType(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          {TYPES.map(t => <option key={t} value={t}>{t || 'All types'}</option>)}
        </select>
      </div>
      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>{['Date', 'Member', 'Type', 'Amount', 'Reference', 'Status'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {txs.map(t => (
                <tr key={t.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-400 text-xs">{t.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3 font-medium">{(t.members as any)?.full_name ?? '—'}</td>
                  <td className="px-4 py-3 text-xs capitalize text-gray-500">{t.transaction_type?.replace(/_/g, ' ')}</td>
                  <td className="px-4 py-3 font-medium">KES {parseFloat(t.amount).toLocaleString()}</td>
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
          {txs.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No transactions</p>}
        </div>
      )}
    </div>
  )
}
