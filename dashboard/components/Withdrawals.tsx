'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Withdrawals() {
  const [txs, setTxs] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('pending')

  useEffect(() => { load() }, [filter])

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('transactions')
      .select('id, amount, status, reference, description, created_at, members!transactions_member_id_fkey(full_name, member_number, phone_number)')
      .eq('transaction_type', 'withdrawal')
      .eq('status', filter)
      .order('created_at', { ascending: false })
      .limit(100)
    setTxs(data ?? [])
    setLoading(false)
  }

  async function markCompleted(id: string) {
    await supabase.from('transactions').update({ status: 'completed' }).eq('id', id)
    setTxs(prev => prev.filter(t => t.id !== id))
  }

  async function markFailed(id: string) {
    await supabase.from('transactions').update({ status: 'failed' }).eq('id', id)
    setTxs(prev => prev.filter(t => t.id !== id))
  }

  const total = txs.reduce((s, t) => s + parseFloat(t.amount ?? 0), 0)

  return (
    <div>
      <div className="flex items-center justify-between mb-5">
        <h2 className="text-xl font-semibold">Withdrawals</h2>
        <div className="flex gap-2">
          {['pending', 'completed', 'failed'].map(s => (
            <button key={s} onClick={() => setFilter(s)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium capitalize transition-colors
                ${filter === s ? 'bg-green-600 text-white' : 'bg-white border text-gray-600 hover:bg-gray-50'}`}>
              {s}
            </button>
          ))}
        </div>
      </div>

      {filter === 'pending' && txs.length > 0 && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg px-4 py-3 mb-4 text-sm text-yellow-800">
          {txs.length} pending withdrawal{txs.length !== 1 ? 's' : ''} totalling{' '}
          <span className="font-semibold">KES {total.toLocaleString('en-KE', { maximumFractionDigits: 0 })}</span>
        </div>
      )}

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>{['Date', 'Member', 'Phone', 'Amount', 'Reference', 'Status', ...(filter === 'pending' ? ['Actions'] : [])].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {txs.map(t => (
                <tr key={t.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-400 text-xs">{t.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3 font-medium">{(t.members as any)?.full_name ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-500 text-xs">{(t.members as any)?.phone_number ?? '—'}</td>
                  <td className="px-4 py-3 font-semibold text-red-600">
                    KES {parseFloat(t.amount).toLocaleString('en-KE', { maximumFractionDigits: 0 })}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-400">{t.reference}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      t.status === 'completed' ? 'bg-green-100 text-green-700' :
                      t.status === 'pending'   ? 'bg-yellow-100 text-yellow-700' :
                      'bg-red-100 text-red-700'}`}>{t.status}</span>
                  </td>
                  {filter === 'pending' && (
                    <td className="px-4 py-3 flex gap-2">
                      <button onClick={() => markCompleted(t.id)}
                        className="text-xs bg-green-600 text-white px-2 py-1 rounded hover:bg-green-700">
                        Mark Done
                      </button>
                      <button onClick={() => markFailed(t.id)}
                        className="text-xs bg-red-100 text-red-600 px-2 py-1 rounded hover:bg-red-200">
                        Failed
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
          {txs.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No {filter} withdrawals</p>}
        </div>
      )}
    </div>
  )
}
