'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function SalaryUpdate() {
  const [accounts, setAccounts] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [editing, setEditing] = useState<string | null>(null)
  const [editVal, setEditVal] = useState('')
  const [saving, setSaving] = useState<string | null>(null)
  const [toast, setToast] = useState('')

  useEffect(() => { load() }, [])

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('fosa_accounts')
      .select('id, account_number, salary_amount, balance, members(id, full_name, member_number, phone_number, status)')
      .order('salary_amount', { ascending: false })
      .limit(300)
    setAccounts(data ?? [])
    setLoading(false)
  }

  async function save(id: string) {
    const val = parseFloat(editVal)
    if (isNaN(val) || val < 0) return
    setSaving(id)
    const { error } = await supabase.from('fosa_accounts').update({ salary_amount: val }).eq('id', id)
    if (!error) {
      setAccounts(prev => prev.map(a => a.id === id ? { ...a, salary_amount: val } : a))
      showToast('Salary updated')
    }
    setEditing(null)
    setSaving(null)
  }

  function showToast(msg: string) {
    setToast(msg)
    setTimeout(() => setToast(''), 2500)
  }

  const filtered = accounts.filter(a => {
    const m = a.members as any
    if (!search) return true
    return m?.full_name?.toLowerCase().includes(search.toLowerCase()) ||
      m?.member_number?.includes(search) ||
      m?.phone_number?.includes(search)
  })

  const withSalary    = accounts.filter(a => parseFloat(a.salary_amount ?? 0) > 0).length
  const totalSalaries = accounts.reduce((s, a) => s + parseFloat(a.salary_amount ?? 0), 0)

  return (
    <div>
      <h2 className="text-xl font-semibold mb-1">Salary Management</h2>
      <p className="text-gray-500 text-sm mb-5">Set members' monthly salary amounts processed through FOSA. Required for FOSA loan eligibility.</p>

      {toast && (
        <div className="fixed top-4 right-4 bg-green-600 text-white text-sm px-4 py-2 rounded-lg shadow z-50">
          {toast}
        </div>
      )}

      {/* Summary */}
      <div className="grid grid-cols-3 gap-4 mb-5">
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
          <p className="text-xs text-gray-400">Members with Salary</p>
          <p className="text-2xl font-bold text-green-700">{withSalary}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
          <p className="text-xs text-gray-400">Total Monthly Payroll</p>
          <p className="text-2xl font-bold text-green-700">
            KES {totalSalaries.toLocaleString('en-KE', { maximumFractionDigits: 0 })}
          </p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
          <p className="text-xs text-gray-400">No Salary Set</p>
          <p className="text-2xl font-bold text-gray-500">{accounts.length - withSalary}</p>
        </div>
      </div>

      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">{filtered.length} accounts</p>
        <input placeholder="Search member..." value={search} onChange={e => setSearch(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm w-56 focus:outline-none focus:ring-2 focus:ring-green-500" />
      </div>

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>{['Member', 'Account #', 'FOSA Balance', 'Monthly Salary', 'Actions'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filtered.map(a => {
                const m = a.members as any
                const isEditing = editing === a.id
                return (
                  <tr key={a.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <p className="font-medium">{m?.full_name}</p>
                      <p className="text-xs text-gray-400">{m?.member_number} · {m?.phone_number}</p>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-gray-400">{a.account_number}</td>
                    <td className="px-4 py-3 text-gray-600">
                      KES {parseFloat(a.balance ?? 0).toLocaleString('en-KE', { maximumFractionDigits: 0 })}
                    </td>
                    <td className="px-4 py-3">
                      {isEditing ? (
                        <input
                          type="number" min="0" autoFocus
                          value={editVal}
                          onChange={e => setEditVal(e.target.value)}
                          onKeyDown={e => { if (e.key === 'Enter') save(a.id); if (e.key === 'Escape') setEditing(null) }}
                          className="border rounded px-2 py-1 text-sm w-32 focus:outline-none focus:ring-2 focus:ring-green-500"
                        />
                      ) : (
                        <span className={parseFloat(a.salary_amount ?? 0) > 0 ? 'font-medium text-green-700' : 'text-gray-300'}>
                          {parseFloat(a.salary_amount ?? 0) > 0
                            ? `KES ${parseFloat(a.salary_amount).toLocaleString('en-KE', { maximumFractionDigits: 0 })}`
                            : 'Not set'}
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {isEditing ? (
                        <div className="flex gap-2">
                          <button disabled={saving === a.id} onClick={() => save(a.id)}
                            className="text-xs bg-green-600 text-white px-2 py-1 rounded hover:bg-green-700 disabled:opacity-50">
                            {saving === a.id ? '...' : 'Save'}
                          </button>
                          <button onClick={() => setEditing(null)}
                            className="text-xs text-gray-400 hover:text-gray-600 px-2 py-1">Cancel</button>
                        </div>
                      ) : (
                        <button onClick={() => { setEditing(a.id); setEditVal(a.salary_amount ?? '0') }}
                          className="text-xs text-blue-600 hover:text-blue-800 px-2 py-1 rounded hover:bg-blue-50">
                          Edit
                        </button>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          {filtered.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No accounts found</p>}
        </div>
      )}
    </div>
  )
}
