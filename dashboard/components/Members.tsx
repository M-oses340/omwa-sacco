'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Members() {
  const [members, setMembers] = useState<any[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => { load() }, [])

  async function load() {
    setLoading(true)
    const { data } = await supabase.from('members')
      .select('id, member_number, full_name, phone_number, role, status, created_at')
      .order('created_at', { ascending: false })
      .limit(200)
    setMembers(data ?? [])
    setLoading(false)
  }

  async function updateStatus(id: string, status: string) {
    await supabase.from('members').update({ status }).eq('id', id)
    setMembers(prev => prev.map(m => m.id === id ? { ...m, status } : m))
  }

  const filtered = members.filter(m =>
    m.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    m.member_number?.includes(search) ||
    m.phone_number?.includes(search)
  )

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold">Members</h2>
        <input placeholder="Search name, number, phone..." value={search} onChange={e => setSearch(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm w-64 focus:outline-none focus:ring-2 focus:ring-green-500" />
      </div>
      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>{['#', 'Name', 'Phone', 'Role', 'Status', 'Joined', 'Actions'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filtered.map(m => (
                <tr key={m.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs">{m.member_number}</td>
                  <td className="px-4 py-3 font-medium">{m.full_name}</td>
                  <td className="px-4 py-3 text-gray-500">{m.phone_number}</td>
                  <td className="px-4 py-3 capitalize text-gray-500">{m.role}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      m.status === 'active' ? 'bg-green-100 text-green-700' :
                      m.status === 'pending' ? 'bg-yellow-100 text-yellow-700' :
                      'bg-red-100 text-red-700'}`}>{m.status}</span>
                  </td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{m.created_at?.split('T')[0]}</td>
                  <td className="px-4 py-3">
                    {m.status === 'pending' && (
                      <button onClick={() => updateStatus(m.id, 'active')}
                        className="text-xs bg-green-600 text-white px-2 py-1 rounded hover:bg-green-700">Activate</button>
                    )}
                    {m.status === 'active' && (
                      <button onClick={() => updateStatus(m.id, 'suspended')}
                        className="text-xs bg-red-100 text-red-600 px-2 py-1 rounded hover:bg-red-200">Suspend</button>
                    )}
                    {m.status === 'suspended' && (
                      <button onClick={() => updateStatus(m.id, 'active')}
                        className="text-xs bg-green-100 text-green-600 px-2 py-1 rounded hover:bg-green-200">Reinstate</button>
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
