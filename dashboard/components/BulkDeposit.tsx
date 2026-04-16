'use client'
import { useRef, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { postDeposit } from '@/app/actions/deposit'

interface Row {
  member_number: string
  account: 'fosa' | 'bosa_savings' | 'bosa_shares'
  amount: number
  reference?: string
  notes?: string
  // resolved at runtime
  _memberId?: string
  _memberName?: string
  _status?: 'pending' | 'ok' | 'error'
  _error?: string
}

const TEMPLATE_CSV = `member_number,account,amount,reference,notes
M-001,fosa,5000,CHQ-001,Monthly contribution
M-002,bosa_savings,3000,,Savings deposit
M-003,bosa_shares,1000,,Share purchase`

export default function BulkDeposit() {
  const fileRef = useRef<HTMLInputElement>(null)
  const [rows, setRows] = useState<Row[]>([])
  const [processing, setProcessing] = useState(false)
  const [progress, setProgress] = useState(0)
  const [done, setDone] = useState(false)
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null)

  function downloadTemplate() {
    const a = document.createElement('a')
    a.href = URL.createObjectURL(new Blob([TEMPLATE_CSV], { type: 'text/csv' }))
    a.download = 'bulk_deposit_template.csv'
    a.click()
  }

  function parseCSV(text: string): Row[] {
    const lines = text.trim().split('\n').filter(Boolean)
    if (lines.length < 2) return []
    const headers = lines[0].split(',').map(h => h.trim().toLowerCase())
    return lines.slice(1).map(line => {
      const vals = line.split(',').map(v => v.trim())
      const obj: any = {}
      headers.forEach((h, i) => { obj[h] = vals[i] ?? '' })
      return {
        member_number: obj.member_number ?? '',
        account: (['fosa', 'bosa_savings', 'bosa_shares'].includes(obj.account) ? obj.account : 'fosa') as Row['account'],
        amount: parseFloat(obj.amount) || 0,
        reference: obj.reference || undefined,
        notes: obj.notes || undefined,
        _status: 'pending',
      }
    }).filter(r => r.member_number && r.amount > 0)
  }

  async function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    const text = await file.text()
    const parsed = parseCSV(text)
    if (!parsed.length) { showToast('No valid rows found in CSV', false); return }

    // Resolve member IDs
    const numbers = [...new Set(parsed.map(r => r.member_number))]
    const { data: members } = await supabase
      .from('members').select('id, full_name, member_number').in('member_number', numbers)
    const memberMap = Object.fromEntries((members ?? []).map(m => [m.member_number, m]))

    const resolved = parsed.map(r => {
      const m = memberMap[r.member_number]
      return m
        ? { ...r, _memberId: m.id, _memberName: m.full_name, _status: 'pending' as const }
        : { ...r, _status: 'error' as const, _error: 'Member not found' }
    })
    setRows(resolved)
    setDone(false)
    setProgress(0)
    if (fileRef.current) fileRef.current.value = ''
  }

  async function process() {
    if (!rows.length) return
    setProcessing(true)
    setProgress(0)
    const updated = [...rows]

    for (let i = 0; i < updated.length; i++) {
      const r = updated[i]
      if (r._status === 'error') { setProgress(i + 1); continue }

      try {
        const result = await postDeposit({
          memberId: r._memberId!,
          memberName: r._memberName ?? '',
          accountType: r.account,
          amount: r.amount,
          method: 'cash',
          reference: r.reference,
          notes: r.notes,
        })
        updated[i] = { ...r, _status: result.ok ? 'ok' : 'error', _error: result.error }
      } catch (err: any) {
        updated[i] = { ...r, _status: 'error', _error: err.message }
      }
      setRows([...updated])
      setProgress(i + 1)
    }

    setProcessing(false)
    setDone(true)
    const ok = updated.filter(r => r._status === 'ok').length
    const fail = updated.filter(r => r._status === 'error').length
    showToast(`Done: ${ok} posted, ${fail} failed`, fail === 0)
  }

  function showToast(msg: string, ok: boolean) {
    setToast({ msg, ok })
    setTimeout(() => setToast(null), 4000)
  }

  function exportResults() {
    const cols = ['member_number', 'member_name', 'account', 'amount', 'reference', 'status', 'error']
    const data = rows.map(r => [
      r.member_number, r._memberName ?? '', r.account,
      r.amount, r.reference ?? '', r._status ?? '', r._error ?? '',
    ])
    const csv = [cols, ...data].map(r => r.join(',')).join('\n')
    const a = document.createElement('a')
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
    a.download = `bulk_deposit_results_${Date.now()}.csv`
    a.click()
  }

  const okCount   = rows.filter(r => r._status === 'ok').length
  const errCount  = rows.filter(r => r._status === 'error').length
  const totalAmt  = rows.filter(r => r._status !== 'error').reduce((s, r) => s + r.amount, 0)

  return (
    <div>
      <h2 className="text-xl font-semibold mb-1">Bulk Deposit</h2>
      <p className="text-gray-500 text-sm mb-5">Upload a CSV to post multiple deposits at once — payroll deductions, group contributions, etc.</p>

      {toast && (
        <div className={`fixed top-4 right-4 text-white text-sm px-4 py-2 rounded-lg shadow z-50 ${toast.ok ? 'bg-green-600' : 'bg-red-600'}`}>
          {toast.msg}
        </div>
      )}

      {/* Upload area */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5 mb-5">
        <div className="flex items-center gap-4 flex-wrap">
          <label className="cursor-pointer bg-green-600 text-white text-sm font-medium px-4 py-2 rounded-lg hover:bg-green-700">
            Choose CSV File
            <input ref={fileRef} type="file" accept=".csv" className="hidden" onChange={onFile} />
          </label>
          <button onClick={downloadTemplate}
            className="text-sm border rounded-lg px-4 py-2 text-gray-600 hover:bg-gray-50">
            ⬇ Download Template
          </button>
          {rows.length > 0 && !processing && (
            <button onClick={() => { setRows([]); setDone(false) }}
              className="text-sm text-gray-400 hover:text-gray-600">Clear</button>
          )}
        </div>

        <div className="mt-4 text-xs text-gray-400 space-y-0.5">
          <p>CSV columns: <span className="font-mono">member_number, account, amount, reference (optional), notes (optional)</span></p>
          <p>Account values: <span className="font-mono">fosa</span> · <span className="font-mono">bosa_savings</span> · <span className="font-mono">bosa_shares</span></p>
        </div>
      </div>

      {/* Preview table */}
      {rows.length > 0 && (
        <>
          <div className="flex items-center justify-between mb-3">
            <div className="flex gap-3 text-sm">
              <span className="text-gray-600">{rows.length} rows</span>
              <span className="text-green-600">KES {totalAmt.toLocaleString('en-KE', { maximumFractionDigits: 0 })} total</span>
              {errCount > 0 && <span className="text-red-500">{errCount} errors</span>}
              {okCount > 0 && <span className="text-green-600">{okCount} posted</span>}
            </div>
            <div className="flex gap-2">
              {done && (
                <button onClick={exportResults}
                  className="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50">
                  ⬇ Export Results
                </button>
              )}
              {!done && (
                <button onClick={process} disabled={processing}
                  className="bg-green-600 text-white text-sm font-medium px-4 py-1.5 rounded-lg hover:bg-green-700 disabled:opacity-50">
                  {processing ? `Processing ${progress}/${rows.length}...` : 'Post All Deposits'}
                </button>
              )}
            </div>
          </div>

          {processing && (
            <div className="h-1.5 bg-gray-100 rounded-full mb-4 overflow-hidden">
              <div className="h-full bg-green-500 transition-all rounded-full"
                style={{ width: `${(progress / rows.length) * 100}%` }} />
            </div>
          )}

          <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>{['Member #', 'Name', 'Account', 'Amount', 'Reference', 'Status'].map(h => (
                  <th key={h} className="px-4 py-3 text-left">{h}</th>
                ))}</tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {rows.map((r, i) => (
                  <tr key={i} className={r._status === 'error' ? 'bg-red-50' : r._status === 'ok' ? 'bg-green-50' : ''}>
                    <td className="px-4 py-2.5 font-mono text-xs">{r.member_number}</td>
                    <td className="px-4 py-2.5 text-gray-700">{r._memberName ?? <span className="text-red-400 italic">not found</span>}</td>
                    <td className="px-4 py-2.5 text-xs capitalize text-gray-500">{r.account.replace(/_/g, ' ')}</td>
                    <td className="px-4 py-2.5 font-medium">KES {r.amount.toLocaleString('en-KE', { maximumFractionDigits: 0 })}</td>
                    <td className="px-4 py-2.5 font-mono text-xs text-gray-400">{r.reference ?? '—'}</td>
                    <td className="px-4 py-2.5">
                      {r._status === 'ok' && <span className="text-xs text-green-600 font-medium">✓ Posted</span>}
                      {r._status === 'error' && <span className="text-xs text-red-500">{r._error}</span>}
                      {r._status === 'pending' && <span className="text-xs text-gray-400">Pending</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  )
}
