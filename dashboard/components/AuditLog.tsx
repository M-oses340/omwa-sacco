'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

const ACTION_COLOR: Record<string, string> = {
  insert: 'bg-green-100 text-green-700',
  update: 'bg-blue-100 text-blue-700',
  delete: 'bg-red-100 text-red-700',
}

export default function AuditLog() {
  const [logs, setLogs] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [table, setTable] = useState('')
  const [tables, setTables] = useState<string[]>([])

  useEffect(() => { load() }, [startDate, endDate, table])

  async function load() {
    setLoading(true)
    let q = supabase
      .from('audit_logs')
      .select('id, action, table_name, record_id, old_data, new_data, created_at, members(full_name, member_number)')
      .order('created_at', { ascending: false })
      .limit(300)
    if (startDate) q = q.gte('created_at', startDate)
    if (endDate)   q = q.lte('created_at', endDate + 'T23:59:59')
    if (table)     q = q.eq('table_name', table)
    const { data } = await q
    const rows = data ?? []
    setLogs(rows)
    // Collect unique table names for filter
    const unique = [...new Set(rows.map((r: any) => r.table_name).filter(Boolean))] as string[]
    if (unique.length) setTables(prev => [...new Set([...prev, ...unique])])
    setLoading(false)
  }

  function exportCsv() {
    const cols = ['date', 'actor', 'action', 'table', 'record_id']
    const rows = filtered.map(r => [
      r.created_at?.split('T')[0],
      (r.members as any)?.full_name ?? 'system',
      r.action,
      r.table_name,
      r.record_id ?? '',
    ])
    const csv = [cols, ...rows].map(r => r.join(',')).join('\n')
    const a = document.createElement('a')
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
    a.download = `audit_log_${Date.now()}.csv`
    a.click()
  }

  const filtered = logs.filter(r => {
    if (!search) return true
    const actor = (r.members as any)?.full_name?.toLowerCase() ?? ''
    return actor.includes(search.toLowerCase()) ||
      r.table_name?.includes(search) ||
      r.record_id?.includes(search)
  })

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold">Audit Log</h2>
        <button onClick={exportCsv}
          className="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50">
          ⬇ Export CSV
        </button>
      </div>

      {/* Filters */}
      <div className="flex gap-2 mb-4 flex-wrap">
        <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
        <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
        <select value={table} onChange={e => setTable(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="">All tables</option>
          {tables.map(t => <option key={t} value={t}>{t}</option>)}
        </select>
        <input placeholder="Search actor, table, record..." value={search} onChange={e => setSearch(e.target.value)}
          className="border rounded-lg px-3 py-1.5 text-sm w-56 focus:outline-none focus:ring-2 focus:ring-green-500" />
        {(startDate || endDate || table || search) && (
          <button onClick={() => { setStartDate(''); setEndDate(''); setTable(''); setSearch('') }}
            className="text-xs text-gray-400 hover:text-gray-600 px-2">Clear</button>
        )}
      </div>

      {loading ? <p className="text-gray-400 text-sm">Loading...</p> : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-xs uppercase sticky top-0">
              <tr>{['Timestamp', 'Actor', 'Action', 'Table', 'Record ID', 'Changes'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filtered.map(r => (
                <tr key={r.id} className="hover:bg-gray-50 align-top">
                  <td className="px-4 py-3 text-xs text-gray-400 whitespace-nowrap">
                    {r.created_at?.replace('T', ' ').slice(0, 19)}
                  </td>
                  <td className="px-4 py-3 text-sm font-medium">
                    {(r.members as any)?.full_name ?? <span className="text-gray-400 italic">system</span>}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium uppercase ${ACTION_COLOR[r.action] ?? 'bg-gray-100 text-gray-600'}`}>
                      {r.action}
                    </span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-600">{r.table_name}</td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-400 max-w-[120px] truncate">{r.record_id ?? '—'}</td>
                  <td className="px-4 py-3 max-w-xs">
                    <ChangeDiff old={r.old_data} next={r.new_data} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered.length === 0 && <p className="text-center text-gray-400 text-sm py-8">No audit records found</p>}
        </div>
      )}
    </div>
  )
}

function ChangeDiff({ old: oldData, next: newData }: { old: any; next: any }) {
  if (!oldData && !newData) return <span className="text-gray-300 text-xs">—</span>
  const o = oldData ?? {}
  const n = newData ?? {}
  const keys = [...new Set([...Object.keys(o), ...Object.keys(n)])]
    .filter(k => o[k] !== n[k])
    .slice(0, 4) // show max 4 changed fields

  if (!keys.length) return <span className="text-gray-300 text-xs">no changes</span>

  return (
    <div className="space-y-0.5">
      {keys.map(k => (
        <div key={k} className="text-xs">
          <span className="text-gray-400">{k}: </span>
          {o[k] !== undefined && (
            <span className="line-through text-red-400 mr-1">{String(o[k]).slice(0, 20)}</span>
          )}
          {n[k] !== undefined && (
            <span className="text-green-600">{String(n[k]).slice(0, 20)}</span>
          )}
        </div>
      ))}
    </div>
  )
}
