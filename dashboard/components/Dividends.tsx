'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Dividends() {
  const [members, setMembers] = useState<any[]>([])
  const [totalShares, setTotalShares] = useState(0)
  const [pool, setPool] = useState('')
  const [year, setYear] = useState(new Date().getFullYear().toString())
  const [preview, setPreview] = useState<any[]>([])
  const [distributing, setDistributing] = useState(false)
  const [history, setHistory] = useState<any[]>([])
  const [loadingHistory, setLoadingHistory] = useState(true)
  const [toast, setToast] = useState('')
  const [confirmed, setConfirmed] = useState(false)

  useEffect(() => {
    loadData()
    loadHistory()
  }, [])

  async function loadData() {
    const { data } = await supabase
      .from('bosa_accounts')
      .select('member_id, shares_balance, members(full_name, member_number)')
    const rows = (data ?? []).filter(r => parseFloat(r.shares_balance) > 0)
    setMembers(rows)
    setTotalShares(rows.reduce((s, r) => s + parseFloat(r.shares_balance), 0))
  }

  async function loadHistory() {
    setLoadingHistory(true)
    const { data } = await supabase
      .from('transactions')
      .select('id, amount, created_at, description, members(full_name, member_number)')
      .eq('transaction_type', 'dividend')
      .order('created_at', { ascending: false })
      .limit(50)
    setHistory(data ?? [])
    setLoadingHistory(false)
  }

  function calcPreview() {
    const p = parseFloat(pool)
    if (!p || p <= 0 || totalShares <= 0) return
    const rows = members.map(m => ({
      ...m,
      dividend: +((parseFloat(m.shares_balance) / totalShares) * p).toFixed(2),
    })).sort((a, b) => b.dividend - a.dividend)
    setPreview(rows)
    setConfirmed(false)
  }

  async function distribute() {
    if (!confirmed) { setConfirmed(true); return }
    setDistributing(true)
    try {
      // Credit each member's FOSA account and record transaction
      for (const m of preview) {
        if (m.dividend <= 0) continue
        const { data: fosa } = await supabase
          .from('fosa_accounts').select('id, balance').eq('member_id', m.member_id).maybeSingle()
        if (!fosa) continue
        const newBal = +(parseFloat(fosa.balance) + m.dividend).toFixed(2)
        await supabase.from('fosa_accounts').update({ balance: newBal }).eq('id', fosa.id)
        await supabase.from('transactions').insert({
          member_id: m.member_id, account_type: 'fosa', transaction_type: 'dividend',
          amount: m.dividend, balance_before: fosa.balance, balance_after: newBal,
          reference: `DIV-${year}-${Date.now()}`,
          description: `Dividend for ${year}`, status: 'completed',
        })
        await supabase.from('notifications').insert({
          member_id: m.member_id, type: 'payment',
          title: `Dividend Credited 🎁`,
          body: `KES ${m.dividend.toLocaleString()} dividend for ${year} has been credited to your FOSA account.`,
          is_read: false,
        })
      }
      showToast(`Distributed KES ${parseFloat(pool).toLocaleString()} to ${preview.length} members`)
      setPool('')
      setPreview([])
      setConfirmed(false)
      loadHistory()
    } catch (e) {
      showToast('Distribution failed')
    }
    setDistributing(false)
  }

  function showToast(msg: string) {
    setToast(msg)
    setTimeout(() => setToast(''), 4000)
  }

  const totalDividend = preview.reduce((s, r) => s + r.dividend, 0)

  return (
    <div>
      <h2 className="text-xl font-semibold mb-5">Dividends</h2>

      {toast && (
        <div className="fixed top-4 right-4 bg-green-600 text-white text-sm px-4 py-2 rounded-lg shadow z-50">
          {toast}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {/* Calculator */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
          <h3 className="font-medium text-gray-700 mb-4">Declare Dividend</h3>

          <div className="bg-blue-50 rounded-lg p-3 mb-4 text-xs text-blue-700">
            <p className="font-medium mb-0.5">Share Capital Summary</p>
            <p>{members.length} eligible members · Total shares: KES {totalShares.toLocaleString('en-KE', { maximumFractionDigits: 0 })}</p>
          </div>

          <div className="flex flex-col gap-3">
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Financial Year</label>
              <input type="number" value={year} onChange={e => setYear(e.target.value)}
                className="border rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Total Dividend Pool (KES)</label>
              <input type="number" min="1" placeholder="e.g. 500000" value={pool}
                onChange={e => { setPool(e.target.value); setPreview([]); setConfirmed(false) }}
                className="border rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-green-500" />
            </div>
            <button onClick={calcPreview} disabled={!pool || parseFloat(pool) <= 0}
              className="bg-blue-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-blue-700 disabled:opacity-40">
              Calculate Preview
            </button>
          </div>
        </div>

        {/* Summary */}
        {preview.length > 0 && (
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
            <h3 className="font-medium text-gray-700 mb-3">Distribution Preview</h3>
            <div className="grid grid-cols-2 gap-3 mb-4">
              <div className="bg-green-50 rounded-lg p-3 text-center">
                <p className="text-xs text-gray-500">Pool</p>
                <p className="font-bold text-green-700">KES {parseFloat(pool).toLocaleString('en-KE', { maximumFractionDigits: 0 })}</p>
              </div>
              <div className="bg-green-50 rounded-lg p-3 text-center">
                <p className="text-xs text-gray-500">Recipients</p>
                <p className="font-bold text-green-700">{preview.length}</p>
              </div>
            </div>
            <div className="max-h-48 overflow-y-auto space-y-1 mb-4 text-xs">
              {preview.slice(0, 20).map(m => (
                <div key={m.member_id} className="flex justify-between py-1 border-b last:border-0">
                  <span className="text-gray-600">{(m.members as any)?.full_name}</span>
                  <span className="font-medium">KES {m.dividend.toLocaleString()}</span>
                </div>
              ))}
              {preview.length > 20 && <p className="text-gray-400 text-center py-1">+{preview.length - 20} more</p>}
            </div>
            {confirmed && (
              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-3 text-xs text-yellow-800">
                This will credit KES {totalDividend.toLocaleString()} to {preview.length} FOSA accounts. Click again to confirm.
              </div>
            )}
            <button onClick={distribute} disabled={distributing}
              className={`w-full rounded-lg py-2 text-sm font-medium disabled:opacity-50 transition-colors
                ${confirmed ? 'bg-red-600 hover:bg-red-700 text-white' : 'bg-green-600 hover:bg-green-700 text-white'}`}>
              {distributing ? 'Distributing...' : confirmed ? 'Confirm & Distribute' : 'Distribute Dividends'}
            </button>
          </div>
        )}
      </div>

      {/* History */}
      <h3 className="font-medium text-gray-700 mb-3">Dividend History</h3>
      {loadingHistory ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>{['Date', 'Member', 'Amount', 'Reference'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {history.map(h => (
                <tr key={h.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-400 text-xs">{h.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3 font-medium">{(h.members as any)?.full_name}</td>
                  <td className="px-4 py-3 font-semibold text-green-600">
                    KES {parseFloat(h.amount).toLocaleString('en-KE', { maximumFractionDigits: 0 })}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-400">{h.reference}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {history.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No dividends distributed yet</p>}
        </div>
      )}
    </div>
  )
}
