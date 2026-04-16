'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Overview() {
  const [stats, setStats] = useState<any>(null)
  const [recent, setRecent] = useState<any[]>([])

  useEffect(() => {
    async function load() {
      const [members, bosa, fosa, loans, pending, pendingWithdrawals, recentTxs] = await Promise.all([
        supabase.from('members').select('id, status', { count: 'exact' }),
        supabase.from('bosa_accounts').select('savings_balance, shares_balance'),
        supabase.from('fosa_accounts').select('balance'),
        supabase.from('loans').select('outstanding_balance, status').in('status', ['disbursed', 'active']),
        supabase.from('loans').select('id', { count: 'exact' }).eq('status', 'pending'),
        supabase.from('transactions').select('id', { count: 'exact' }).eq('transaction_type', 'withdrawal').eq('status', 'pending'),
        supabase.from('transactions')
          .select('id, transaction_type, amount, status, created_at, members(full_name)')
          .order('created_at', { ascending: false })
          .limit(8),
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
        pendingWithdrawals: pendingWithdrawals.count ?? 0,
      })
      setRecent(recentTxs.data ?? [])
    }
    load()
  }, [])

  if (!stats) return <div className="text-gray-400 text-sm">Loading...</div>

  const cards = [
    { label: 'Active Members',       value: stats.activeMembers,             sub: `${stats.totalMembers} total` },
    { label: 'BOSA Savings',         value: fmt(stats.totalSavings),         sub: `Shares: ${fmt(stats.totalShares)}` },
    { label: 'FOSA Balances',        value: fmt(stats.totalFosa),            sub: 'Total FOSA holdings' },
    { label: 'Loan Portfolio',       value: fmt(stats.totalLoans),           sub: 'Outstanding balance' },
    { label: 'Pending Loan Approvals', value: stats.pendingLoans,            sub: 'Loans awaiting review', alert: stats.pendingLoans > 0 },
    { label: 'Pending Withdrawals',  value: stats.pendingWithdrawals,        sub: 'Awaiting processing', alert: stats.pendingWithdrawals > 0 },
  ]

  const txIcon: Record<string, string> = {
    deposit: '⬇️', withdrawal: '⬆️', loan_disbursement: '💰',
    loan_repayment: '✅', transfer: '↔️', dividend: '🎁',
  }

  return (
    <div>
      <h2 className="text-xl font-semibold mb-6">Overview</h2>
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        {cards.map(c => (
          <div key={c.label} className={`rounded-xl shadow-sm p-5 border ${c.alert ? 'bg-yellow-50 border-yellow-200' : 'bg-white border-gray-100'}`}>
            <p className="text-xs text-gray-500 mb-1">{c.label}</p>
            <p className={`text-2xl font-bold ${c.alert ? 'text-yellow-700' : 'text-green-700'}`}>{c.value}</p>
            <p className="text-xs text-gray-400 mt-1">{c.sub}</p>
          </div>
        ))}
      </div>

      <h3 className="font-medium text-gray-700 mb-3">Recent Activity</h3>
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 divide-y divide-gray-50">
        {recent.length === 0 && <p className="text-center text-gray-400 text-sm py-6">No recent transactions</p>}
        {recent.map(t => (
          <div key={t.id} className="flex items-center gap-3 px-4 py-3">
            <span className="text-lg">{txIcon[t.transaction_type] ?? '🔄'}</span>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{(t.members as any)?.full_name ?? '—'}</p>
              <p className="text-xs text-gray-400 capitalize">{t.transaction_type?.replace(/_/g, ' ')}</p>
            </div>
            <div className="text-right">
              <p className="text-sm font-semibold text-gray-800">KES {parseFloat(t.amount).toLocaleString('en-KE', { maximumFractionDigits: 0 })}</p>
              <p className="text-xs text-gray-400">{t.created_at?.split('T')[0]}</p>
            </div>
            <span className={`ml-2 px-2 py-0.5 rounded-full text-xs font-medium ${
              t.status === 'completed' ? 'bg-green-100 text-green-700' :
              t.status === 'pending'   ? 'bg-yellow-100 text-yellow-700' :
              'bg-red-100 text-red-700'}`}>{t.status}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function fmt(n: number) {
  return `KES ${n.toLocaleString('en-KE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
