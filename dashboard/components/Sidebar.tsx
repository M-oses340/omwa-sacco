'use client'
import { supabase } from '@/lib/supabase'

const NAV = [
  { id: 'overview',     label: 'Overview',      icon: '📊' },
  { id: 'members',      label: 'Members',        icon: '👥' },
  { id: 'loans',        label: 'Loans',          icon: '💰' },
  { id: 'transactions', label: 'Transactions',   icon: '🔄' },
  { id: 'reports',      label: 'Reports',        icon: '📋' },
]

export default function Sidebar({ page, setPage, member }: { page: string; setPage: (p: string) => void; member: any }) {
  return (
    <aside className="w-56 bg-green-800 text-white flex flex-col h-full">
      <div className="p-5 border-b border-green-700">
        <h1 className="font-bold text-lg">Omwa Sacco</h1>
        <p className="text-green-300 text-xs mt-1 capitalize">{member?.role}</p>
      </div>
      <nav className="flex-1 p-3 flex flex-col gap-1">
        {NAV.map(n => (
          <button key={n.id} onClick={() => setPage(n.id)}
            className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-left transition-colors
              ${page === n.id ? 'bg-green-600 font-medium' : 'hover:bg-green-700'}`}>
            <span>{n.icon}</span>{n.label}
          </button>
        ))}
      </nav>
      <div className="p-4 border-t border-green-700">
        <p className="text-xs text-green-300 truncate mb-2">{member?.full_name}</p>
        <button onClick={() => supabase.auth.signOut()}
          className="text-xs text-green-300 hover:text-white">Sign out</button>
      </div>
    </aside>
  )
}
