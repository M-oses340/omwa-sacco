'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import MemberDetail from './MemberDetail'

export default function Members() {
  const [members, setMembers] = useState<any[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<any>(null)
  const [statusFilter, setStatusFilter] = useState('all')

  useEffect(() => { load() }, [])

  async function load() {
    setLoading(true)
    const { data } = await supabase.from('members')
      .select('id, member_number, full_name, phone_number, role, status, created_at')
      .order('created_at', { ascending: false })
      .limit(300)
    setMembers(data ?? [])
    setLoading(false)
  }

  async function updateStatus(id: string, status: string) {
    await supabase.from('members').update({ status }).eq('id', id)
    setMembers(prev => prev.map(m => m.id === id ? { ...m, status } : m))
    if (selected?.id === id) setSelected((s: any) => ({ ...s, status }))
  }

  const filtered = members.filter(m => {
    const matchSearch =
      m.full_name?.toLowerCase().includes(search.toLowerCase()) ||
      m.member_number?.includes(search) ||
      m.phone_number?.includes(search)
    const matchStatus = statusFilter === 'all' || m.status === statusFilter
    return matchSearch && matchStatus
  })

  const counts = {
    all: members.length,
    active: members.filter(m => m.status === 'active').length,
    pending: members.filter(m => m.status === 'pending').length,
    suspended: members.filter(m => m.status === 'suspended').length,
  }

  return (
    <div>
      {selected && (
        <MemberDetail member={selected} onClose={() => setSelected(null)} />
      )}

      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Members</h2>
        <input placeholder="Search name, number, phone..." value={search} onChange={e => setSearch(e.target.value)}
          className="border dark:border-gray-700 rounded-lg px-3 py-1.5 text-sm w-64 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500" />
      </div>

      {/* Status filter tabs */}
      <div className="flex gap-2 mb-4">
        {(['all', 'active', 'pending', 'suspended'] as const).map(s => (
          <button key={s} onClick={() => setStatusFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium capitalize transition-colors
              ${statusFilter === s ? 'bg-green-600 text-white' : 'bg-white dark:bg-gray-900 border dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
            {s} ({counts[s]})
          </button>
        ))}
      </div>

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500 dark:text-gray-400 text-xs uppercase">
              <tr>{['#', 'Name', 'Phone', 'Role', 'Status', 'Joined', 'Actions'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {filtered.map(m => (
                <tr key={m.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/60 cursor-pointer"
                  onClick={() => setSelected(m)}>
                  <td className="px-4 py-3 font-mono text-xs text-gray-500 dark:text-gray-400">{m.member_number}</td>
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-gray-100">{m.full_name}</td>
                  <td className="px-4 py-3 text-gray-500 dark:text-gray-400">{m.phone_number}</td>
                  <td className="px-4 py-3 capitalize text-gray-500 dark:text-gray-400">{m.role}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      m.status === 'active'    ? 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400' :
                      m.status === 'pending'   ? 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400' :
                      'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-400'}`}>{m.status}</span>
                  </td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{m.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3" onClick={e => e.stopPropagation()}>
                    {m.status === 'pending' && (
                      <button onClick={() => updateStatus(m.id, 'active')}
                        className="text-xs bg-green-600 text-white px-2 py-1 rounded hover:bg-green-700">Activate</button>
                    )}
                    {m.status === 'active' && (
                      <button onClick={() => updateStatus(m.id, 'suspended')}
                        className="text-xs bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-400 px-2 py-1 rounded hover:bg-red-200">Suspend</button>
                    )}
                    {m.status === 'suspended' && (
                      <button onClick={() => updateStatus(m.id, 'active')}
                        className="text-xs bg-green-100 dark:bg-green-900/40 text-green-600 dark:text-green-400 px-2 py-1 rounded hover:bg-green-200">Reinstate</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No members found</p>}
        </div>
      )}
    </div>
  )
}
