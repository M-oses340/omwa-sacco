'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Overview() {
  const [stats, setStats] = useState<any>(null)

  useEffect(() => {
    async function load() {
      const [members, bosa, fosa, loans, pending] = await Promise.all([
        supabase.from('members').select('id, status', { count: 'exact' }),
        supabase.from('bosa_accounts').select('savings_balance, shares_balance'),
        supabase.from('fosa_accounts').select('balance'),
        supabase.from('loans').select('outstanding_balance, status').in('status', ['disbursed', 'active']),
        supabase.from('loans').select('id', { count: 'exact' }).eq('status', 'pending'),
      ])
      const totalSavings = (bosa.data ?? []).reduce((s, r) => s + parseFloat(r.savings_balance ?? 0), 0)
      const totalShares  = (bosa.data ?? []).reduce((s, r) => s + parseFloat(r.shares_balance ?? 0), 0)
      const totalFosa    = (fosa.data ?? []).reduce((s, r) => s + parseFloat(r.balance ?? 0), 0)
      const totalLoans   = (loans.data ?? []).reduce((s, r) => s + parseFloat(r.outstanding_balance ?? 0), 0)
      const activeMembers = (members.data ?? []).filter(m => m.status === 'active').length
      setStats({
        totalMembers: members.count ?? 0, activeMembers,
        totalSavings, totalShares, totalFosa, totalLoans,
        pendingLoans: pending.count ?? 0,
      })
    }
    load()
  }, [])

  if (!stats) return <div className="text-gray-400 text-sm">Loading...</div>

  const cards = [
    { label: 'Active Members',    value: stats.activeMembers,                  sub: `${stats.totalMembers} total` },
    { label: 'BOSA Savings',      value: fmt(stats.totalSavings),              sub: `Shares: ${fmt(stats.totalShares)}` },
    { label: 'FOSA Balances',     value: fmt(stats.totalFosa),                 sub: 'Total FOSA holdings' },
    { label: 'Loan Portfolio',    value: fmt(stats.totalLoans),                sub: 'Outstanding balance' },
    { label: 'Pending Approvals', value: stats.pendingLoans,                   sub: 'Loans awaiting review' },
  ]

  return (
    <div>
      <h2 className="text-xl font-semibold mb-6">Overview</h2>
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        {cards.map(c => (
          <div key={c.label} className="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
            <p className="text-xs text-gray-500 mb-1">{c.label}</p>
            <p className="text-2xl font-bold text-green-700">{c.value}</p>
            <p className="text-xs text-gray-400 mt-1">{c.sub}</p>
          </div>
        ))}
      </div>
    </div>
  )
}

function fmt(n: number) {
  return `KES ${n.toLocaleString('en-KE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
