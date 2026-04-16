'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

const ROLES = ['member', 'secretary', 'treasurer', 'chairman', 'admin']

export default function Settings() {
  const [members, setMembers] = useState<any[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState<string | null>(null)
  const [toast, setToast] = useState('')

  useEffect(() => { load() }, [])

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('members')
      .select('id, member_number, full_name, phone_number, role, status')
      .order('full_name')
      .limit(300)
    setMembers(data ?? [])
    setLoading(false)
  }

  async function updateRole(id: string, role: string) {
    setSaving(id)
    const { error } = await supabase.from('members').update({ role }).eq('id', id)
    if (!error) {
      setMembers(prev => prev.map(m => m.id === id ? { ...m, role } : m))
      showToast('Role updated')
    }
    setSaving(null)
  }

  function showToast(msg: string) {
    setToast(msg)
    setTimeout(() => setToast(''), 2500)
  }

  const filtered = members.filter(m =>
    m.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    m.member_number?.includes(search)
  )

  return (
    <div>
      <h2 className="text-xl font-semibold mb-1 text-gray-900 dark:text-gray-100">Settings</h2>
      <p className="text-gray-500 dark:text-gray-400 text-sm mb-5">Manage member roles and access levels.</p>

      {toast && (
        <div className="fixed top-4 right-4 bg-green-600 text-white text-sm px-4 py-2 rounded-lg shadow z-50">
          {toast}
        </div>
      )}

      <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 p-5 mb-6">
        <h3 className="font-medium text-gray-700 dark:text-gray-300 mb-3">Role Permissions</h3>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3 text-xs text-gray-600 dark:text-gray-400">
          {[
            { role: 'member',    perms: 'View own account only' },
            { role: 'secretary', perms: 'View members & reports' },
            { role: 'treasurer', perms: 'Approve & disburse loans' },
            { role: 'chairman',  perms: 'Approve & disburse loans' },
            { role: 'admin',     perms: 'Full access' },
          ].map(r => (
            <div key={r.role} className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
              <p className="font-semibold capitalize text-gray-800 dark:text-gray-200">{r.role}</p>
              <p className="text-gray-500 dark:text-gray-400 mt-0.5">{r.perms}</p>
            </div>
          ))}
        </div>
      </div>

      <div className="flex items-center justify-between mb-4">
        <h3 className="font-medium text-gray-700 dark:text-gray-300">Member Roles</h3>
        <input placeholder="Search member..." value={search} onChange={e => setSearch(e.target.value)}
          className="border dark:border-gray-700 rounded-lg px-3 py-1.5 text-sm w-56 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500" />
      </div>

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500 dark:text-gray-400 text-xs uppercase">
              <tr>{['#', 'Name', 'Phone', 'Status', 'Role'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {filtered.map(m => (
                <tr key={m.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/60">
                  <td className="px-4 py-3 font-mono text-xs text-gray-400">{m.member_number}</td>
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-gray-100">{m.full_name}</td>
                  <td className="px-4 py-3 text-gray-500 dark:text-gray-400 text-xs">{m.phone_number}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      m.status === 'active'  ? 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400' :
                      m.status === 'pending' ? 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400' :
                      'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-400'}`}>{m.status}</span>
                  </td>
                  <td className="px-4 py-3">
                    <select value={m.role} disabled={saving === m.id} onChange={e => updateRole(m.id, e.target.value)}
                      className="border dark:border-gray-700 rounded px-2 py-1 text-xs bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500 disabled:opacity-50">
                      {ROLES.map(r => <option key={r} value={r}>{r}</option>)}
                    </select>
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
