'use client'
import { useState } from 'react'
import { callFunction } from '@/lib/supabase'

const REPORTS = [
  { id: 'member_register',      label: 'Member Register',       dateFilter: false },
  { id: 'new_members',          label: 'New Members',           dateFilter: true  },
  { id: 'dormant_members',      label: 'Dormant Members',       dateFilter: false },
  { id: 'savings_summary',      label: 'Savings Summary',       dateFilter: false },
  { id: 'deposit_collection',   label: 'Deposit Collection',    dateFilter: true  },
  { id: 'fosa_balances',        label: 'FOSA Balances',         dateFilter: false },
  { id: 'loan_book',            label: 'Loan Book',             dateFilter: false },
  { id: 'loan_disbursements',   label: 'Loan Disbursements',    dateFilter: true  },
  { id: 'arrears',              label: 'Arrears Report',        dateFilter: false },
  { id: 'npl',                  label: 'Non-Performing Loans',  dateFilter: false },
  { id: 'par',                  label: 'Portfolio at Risk',     dateFilter: false },
  { id: 'income_statement',     label: 'Income Statement',      dateFilter: true  },
  { id: 'balance_sheet',        label: 'Balance Sheet',         dateFilter: false },
  { id: 'cash_flow',            label: 'Cash Flow',             dateFilter: true  },
  { id: 'withdrawal_report',    label: 'Withdrawal Report',     dateFilter: true  },
  { id: 'daily_summary',        label: 'Daily Summary',         dateFilter: true  },
  { id: 'mpesa_reconciliation', label: 'M-Pesa Reconciliation', dateFilter: true  },
  { id: 'share_capital',        label: 'Share Capital',         dateFilter: false },
  { id: 'dividend_report',      label: 'Dividend Report',       dateFilter: true  },
  { id: 'pending_approvals',    label: 'Pending Approvals',     dateFilter: false },
  { id: 'audit_trail',          label: 'Audit Trail',           dateFilter: true  },
]

export default function Reports() {
  const [selected, setSelected] = useState(REPORTS[0].id)
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [result, setResult] = useState<any>(null)
  const [loading, setLoading] = useState(false)

  const report = REPORTS.find(r => r.id === selected)!

  async function run() {
    setLoading(true); setResult(null)
    const params = report.dateFilter ? { start_date: startDate || undefined, end_date: endDate || undefined } : undefined
    const data = await callFunction('reports', { report: selected, params })
    setResult(data)
    setLoading(false)
  }

  const cols = result?.data?.[0] ? Object.keys(result.data[0]) : []

  return (
    <div>
      <h2 className="text-xl font-semibold mb-5">Reports</h2>
      <div className="flex gap-4 mb-5 flex-wrap">
        <select value={selected} onChange={e => { setSelected(e.target.value); setResult(null) }}
          className="border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          {REPORTS.map(r => <option key={r.id} value={r.id}>{r.label}</option>)}
        </select>
        {report.dateFilter && <>
          <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)}
            className="border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)}
            className="border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
        </>}
        <button onClick={run} disabled={loading}
          className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 disabled:opacity-50">
          {loading ? 'Running...' : 'Run Report'}
        </button>
      </div>

      {result?.summary && (
        <div className="flex gap-3 mb-4 flex-wrap">
          {Object.entries(result.summary).map(([k, v]) => (
            <div key={k} className="bg-green-50 border border-green-100 rounded-lg px-4 py-2">
              <p className="text-xs text-green-600 capitalize">{k.replace(/_/g, ' ')}</p>
              <p className="font-bold text-green-800">{typeof v === 'number' ? v.toLocaleString() : String(v)}</p>
            </div>
          ))}
        </div>
      )}

      {result?.data && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-auto max-h-[60vh]">
          <table className="w-full text-xs">
            <thead className="bg-gray-50 text-gray-500 uppercase sticky top-0">
              <tr>{cols.map(c => <th key={c} className="px-3 py-2 text-left whitespace-nowrap">{c.replace(/_/g, ' ')}</th>)}</tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {result.data.map((row: any, i: number) => (
                <tr key={i} className="hover:bg-gray-50">
                  {cols.map(c => (
                    <td key={c} className="px-3 py-2 whitespace-nowrap text-gray-700">
                      {typeof row[c] === 'object' ? JSON.stringify(row[c]) : String(row[c] ?? '—')}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
          {result.data.length === 0 && <p className="text-center text-gray-400 py-8">No data</p>}
        </div>
      )}

      {result?.error && <p className="text-red-500 text-sm mt-4">{result.error}</p>}
    </div>
  )
}
