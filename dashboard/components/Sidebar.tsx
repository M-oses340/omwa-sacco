'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

const NAV = [
  { id: 'overview',       label: 'Overview',        icon: '📊' },
  { id: 'members',        label: 'Members',          icon: '👥' },
  { id: 'loans',          label: 'Loans',            icon: '💰', badge: 'pendingLoans' },
  { id: 'withdrawals',    label: 'Withdrawals',      icon: '💸', badge: 'pendingWithdrawals' },
  { id: 'transactions',   label: 'Transactions',     icon: '🔄' },
  { id: 'manual_deposit', label: 'Manual Deposit',   icon: '💵' },
  { id: 'salary',         label: 'Salary',           icon: '🏦' },
  { id: 'dividends',      label: 'Dividends',        icon: '🎁' },
  { id: 'notifications',  label: 'Notifications',    icon: '🔔' },
  { id: 'reports',        label: 'Reports',          icon: '📋' },
  { id: 'audit',          label: 'Audit Log',        icon: '🔍' },
  { id: 'settings',       label: 'Settings',         icon: '⚙️' },
]

export default function Sidebar({ page, setPage, member }: { page: string; setPage: (p: string) => void; member: any }) {
  const [badges, setBadges] = useState<Record<string, number>>({ pendingLoans: 0, pendingWithdrawals: 0 })

  useEffect(() => {
    async function loadBadges() {
      const [loans, withdrawals] = await Promise.all([
        supabase.from('loans').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
        supabase.from('transactions').select('id', { count: 'exact', head: true })
          .eq('transaction_type', 'withdrawal').eq('status', 'pending'),
      ])
      setBadges({
        pendingLoans: loans.count ?? 0,
        pendingWithdrawals: withdrawals.count ?? 0,
      })
    }
    loadBadges()
    // Refresh every 60s
    const interval = setInterval(loadBadges, 60_000)
    return () => clearInterval(interval)
  }, [])

  return (
    <aside className="w-56 bg-green-800 text-white flex flex-col h-full">
      <div className="p-5 border-b border-green-700">
        <h1 className="font-bold text-lg">Omwa Sacco</h1>
        <p className="text-green-300 text-xs mt-1 capitalize">{member?.role}</p>
      </div>
      <nav className="flex-1 p-3 flex flex-col gap-1 overflow-y-auto">
        {NAV.map(n => {
          const count = n.badge ? (badges[n.badge] ?? 0) : 0
          return (
            <button key={n.id} onClick={() => setPage(n.id)}
              className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-left transition-colors
                ${page === n.id ? 'bg-green-600 font-medium' : 'hover:bg-green-700'}`}>
              <span>{n.icon}</span>
              <span className="flex-1">{n.label}</span>
              {count > 0 && (
                <span className="bg-red-500 text-white text-xs font-bold rounded-full min-w-[18px] h-[18px] flex items-center justify-center px-1">
                  {count > 99 ? '99+' : count}
                </span>
              )}
            </button>
          )
        })}
      </nav>
      <div className="p-4 border-t border-green-700">
        <p className="text-xs text-green-300 truncate mb-2">{member?.full_name}</p>
        <button onClick={() => supabase.auth.signOut()}
          className="text-xs text-green-300 hover:text-white">Sign out</button>
      </div>
    </aside>
  )
}
