'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

interface Props {
  member: any
  onClose: () => void
}

type Tab = 'accounts' | 'loans' | 'transactions' | 'statement'

const CREDIT_TYPES = new Set(['deposit', 'loan_disbursement', 'dividend', 'share_purchase'])

export default function MemberDetail({ member, onClose }: Props) {
  const [bosa, setBosa]   = useState<any>(null)
  const [fosa, setFosa]   = useState<any>(null)
  const [loans, setLoans] = useState<any[]>([])
  const [txs, setTxs]     = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab]     = useState<Tab>('accounts')

  useEffect(() => {
    async function load() {
      const [b, f, l, t] = await Promise.all([
        supabase.from('bosa_accounts').select('*').eq('member_id', member.id).maybeSingle(),
        supabase.from('fosa_accounts').select('*').eq('member_id', member.id).maybeSingle(),
        supabase.from('loans').select('*').eq('member_id', member.id).order('created_at', { ascending: false }),
        supabase.from('transactions').select('*').eq('member_id', member.id)
          .order('created_at', { ascending: true }).limit(200),
      ])
      setBosa(b.data)
      setFosa(f.data)
      setLoans(l.data ?? [])
      setTxs(t.data ?? [])
      setLoading(false)
    }
    load()
  }, [member.id])

  // Build running-balance statement (oldest → newest, then reversed for display)
  const statement = [...txs].map((t, i, arr) => {
    const isCredit = CREDIT_TYPES.has(t.transaction_type)
    const balance  = parseFloat(t.balance_after ?? t.balance_before ?? 0)
    return { ...t, isCredit, runningBalance: balance }
  }).reverse()

  function printStatement() {
    const win = window.open('', '_blank')
    if (!win) return
    const rows = statement.map(t => `
      <tr>
        <td>${t.created_at?.split('T')[0]}</td>
        <td>${t.transaction_type?.replace(/_/g, ' ')}</td>
        <td>${t.reference ?? ''}</td>
        <td style="color:${t.isCredit ? 'green' : 'red'}">${t.isCredit ? '+' : '-'}${parseFloat(t.amount).toLocaleString('en-KE', { minimumFractionDigits: 2 })}</td>
        <td>${t.runningBalance.toLocaleString('en-KE', { minimumFractionDigits: 2 })}</td>
        <td>${t.status}</td>
      </tr>`).join('')
    win.document.write(`<html><head><title>Statement - ${member.full_name}</title>
      <style>body{font-family:sans-serif;font-size:12px;padding:20px}
      h2{margin-bottom:4px}p{color:#666;margin:2px 0}
      table{width:100%;border-collapse:collapse;margin-top:16px}
      th{background:#f5f5f5;padding:6px 8px;text-align:left;font-size:11px;text-transform:uppercase}
      td{padding:6px 8px;border-bottom:1px solid #eee}</style></head><body>
      <h2>Account Statement</h2>
      <p>${member.full_name} · ${member.member_number} · ${member.phone_number}</p>
      <p>Generated: ${new Date().toLocaleDateString('en-KE')}</p>
      <table><thead><tr><th>Date</th><th>Type</th><th>Reference</th><th>Amount</th><th>Balance</th><th>Status</th></tr></thead>
      <tbody>${rows}</tbody></table></body></html>`)
    win.document.close()
    win.print()
  }

  function exportStatement() {
    const cols = ['date', 'type', 'reference', 'debit', 'credit', 'balance', 'status']
    const data = statement.map(t => [
      t.created_at?.split('T')[0],
      t.transaction_type,
      t.reference ?? '',
      t.isCredit ? '' : parseFloat(t.amount).toFixed(2),
      t.isCredit ? parseFloat(t.amount).toFixed(2) : '',
      t.runningBalance.toFixed(2),
      t.status,
    ])
    const csv = [cols, ...data].map(r => r.join(',')).join('\n')
    const a = document.createElement('a')
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
    a.download = `statement_${member.member_number}_${Date.now()}.csv`
    a.click()
  }

  return (
    <div className="fixed inset-0 bg-black/40 dark:bg-black/60 z-50 flex items-start justify-end" onClick={onClose}>
      <div className="bg-white dark:bg-gray-900 h-full w-full max-w-2xl shadow-2xl overflow-y-auto"
        onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b dark:border-gray-800 sticky top-0 bg-white dark:bg-gray-900 z-10">
          <div>
            <h2 className="font-semibold text-lg text-gray-900 dark:text-gray-100">{member.full_name}</h2>
            <p className="text-xs text-gray-400 font-mono">{member.member_number} · {member.phone_number}</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 text-xl leading-none">✕</button>
        </div>

        {loading ? (
          <div className="p-6 text-gray-400 text-sm">Loading...</div>
        ) : (
          <div className="p-6">
            {/* Status badges */}
            <div className="flex gap-2 mb-5">
              <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                member.status === 'active'  ? 'bg-green-100 text-green-700' :
                member.status === 'pending' ? 'bg-yellow-100 text-yellow-700' :
                'bg-red-100 text-red-700'}`}>{member.status}</span>
              <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-700 capitalize">{member.role}</span>
              <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
                Joined {member.created_at?.split('T')[0]}
              </span>
            </div>

            <div className="flex gap-1 mb-5 border-b dark:border-gray-800">
              {(['accounts', 'loans', 'transactions', 'statement'] as Tab[]).map(t => (
                <button key={t} onClick={() => setTab(t)}
                  className={`px-4 py-2 text-sm font-medium capitalize border-b-2 transition-colors -mb-px
                    ${tab === t ? 'border-green-600 text-green-700 dark:text-green-400' : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}`}>
                  {t}
                </button>
              ))}
            </div>

            {tab === 'accounts' && (
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-blue-50 dark:bg-blue-900/20 rounded-xl p-4 border border-blue-100 dark:border-blue-800">
                  <p className="text-xs text-blue-500 dark:text-blue-400 font-medium mb-2">BOSA Account</p>
                  {bosa ? (
                    <>
                      <p className="font-mono text-xs text-gray-500 dark:text-gray-400 mb-3">{bosa.account_number}</p>
                      <div className="space-y-1.5">
                        <Row label="Savings"         value={fmt(bosa.savings_balance)} />
                        <Row label="Shares"          value={fmt(bosa.shares_balance)} />
                        <Row label="Loan limit (5×)" value={fmt(parseFloat(bosa.savings_balance ?? 0) * 5)} />
                      </div>
                    </>
                  ) : <p className="text-xs text-gray-400">No BOSA account</p>}
                </div>
                <div className="bg-green-50 dark:bg-green-900/20 rounded-xl p-4 border border-green-100 dark:border-green-800">
                  <p className="text-xs text-green-600 dark:text-green-400 font-medium mb-2">FOSA Account</p>
                  {fosa ? (
                    <>
                      <p className="font-mono text-xs text-gray-500 dark:text-gray-400 mb-3">{fosa.account_number}</p>
                      <div className="space-y-1.5">
                        <Row label="Balance" value={fmt(fosa.balance)} />
                        <Row label="Salary"  value={fmt(fosa.salary_amount)} />
                      </div>
                    </>
                  ) : <p className="text-xs text-gray-400">No FOSA account</p>}
                </div>
              </div>
            )}

            {tab === 'loans' && (
              <div className="space-y-3">
                {loans.length === 0 && <p className="text-gray-400 text-sm">No loans</p>}
                {loans.map(l => (
                  <div key={l.id} className="border dark:border-gray-700 rounded-xl p-4">
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-mono text-xs text-gray-500 dark:text-gray-400">{l.loan_number}</span>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${statusColor(l.status)}`}>{l.status}</span>
                    </div>
                    <p className="font-medium capitalize text-sm mb-2 text-gray-900 dark:text-gray-100">{l.loan_type?.replace(/_/g, ' ')}</p>
                    <div className="grid grid-cols-3 gap-2 text-xs">
                      <div><p className="text-gray-400">Principal</p><p className="font-medium text-gray-900 dark:text-gray-100">{fmt(l.principal)}</p></div>
                      <div><p className="text-gray-400">Outstanding</p><p className="font-medium text-gray-900 dark:text-gray-100">{fmt(l.outstanding_balance)}</p></div>
                      <div><p className="text-gray-400">Monthly</p><p className="font-medium text-gray-900 dark:text-gray-100">{fmt(l.monthly_repayment)}</p></div>
                    </div>
                    {l.due_date && <p className="text-xs text-gray-400 mt-2">Due: {l.due_date}</p>}
                  </div>
                ))}
              </div>
            )}

            {tab === 'transactions' && (
              <div className="space-y-1">
                {txs.length === 0 && <p className="text-gray-400 text-sm">No transactions</p>}
                {[...txs].reverse().map(t => (
                  <div key={t.id} className="flex items-center justify-between py-2.5 border-b dark:border-gray-800 last:border-0">
                    <div>
                      <p className="text-sm capitalize text-gray-900 dark:text-gray-100">{t.transaction_type?.replace(/_/g, ' ')}</p>
                      <p className="text-xs text-gray-400">{t.created_at?.split('T')[0]} · {t.reference}</p>
                    </div>
                    <div className="text-right">
                      <p className={`text-sm font-semibold ${CREDIT_TYPES.has(t.transaction_type) ? 'text-green-600 dark:text-green-400' : 'text-red-500 dark:text-red-400'}`}>
                        {CREDIT_TYPES.has(t.transaction_type) ? '+' : '-'}{fmt(t.amount)}
                      </p>
                      <span className={`text-xs ${
                        t.status === 'completed' ? 'text-green-500' :
                        t.status === 'pending'   ? 'text-yellow-500' : 'text-red-400'}`}>{t.status}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {tab === 'statement' && (
              <div>
                <div className="flex gap-2 mb-4">
                  <button onClick={printStatement}
                    className="text-xs border dark:border-gray-700 rounded-lg px-3 py-1.5 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800">
                    🖨 Print
                  </button>
                  <button onClick={exportStatement}
                    className="text-xs border dark:border-gray-700 rounded-lg px-3 py-1.5 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800">
                    ⬇ Export CSV
                  </button>
                </div>
                {statement.length === 0 ? (
                  <p className="text-gray-400 text-sm">No transactions</p>
                ) : (
                  <div className="overflow-auto max-h-[55vh]">
                    <table className="w-full text-xs">
                      <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500 dark:text-gray-400 uppercase sticky top-0">
                        <tr>{['Date', 'Type', 'Reference', 'Debit', 'Credit', 'Balance', 'Status'].map(h => (
                          <th key={h} className="px-3 py-2 text-left whitespace-nowrap">{h}</th>
                        ))}</tr>
                      </thead>
                      <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                        {statement.map(t => (
                          <tr key={t.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/60">
                            <td className="px-3 py-2 text-gray-400 whitespace-nowrap">{t.created_at?.split('T')[0]}</td>
                            <td className="px-3 py-2 capitalize whitespace-nowrap text-gray-900 dark:text-gray-100">{t.transaction_type?.replace(/_/g, ' ')}</td>
                            <td className="px-3 py-2 font-mono text-gray-400">{t.reference ?? '—'}</td>
                            <td className="px-3 py-2 text-red-500 dark:text-red-400">{!t.isCredit ? fmt(t.amount) : ''}</td>
                            <td className="px-3 py-2 text-green-600 dark:text-green-400">{t.isCredit ? fmt(t.amount) : ''}</td>
                            <td className="px-3 py-2 font-medium text-gray-900 dark:text-gray-100">{fmt(t.runningBalance)}</td>
                            <td className="px-3 py-2">
                              <span className={`px-1.5 py-0.5 rounded text-xs ${
                                t.status === 'completed' ? 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400' :
                                t.status === 'pending'   ? 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400' :
                                'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-400'}`}>{t.status}</span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-xs">
      <span className="text-gray-500">{label}</span>
      <span className="font-medium">{value}</span>
    </div>
  )
}

function fmt(n: any) {
  return `KES ${parseFloat(n ?? 0).toLocaleString('en-KE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}

function statusColor(s: string) {
  return s === 'disbursed' ? 'bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-400' :
         s === 'repaid'    ? 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400' :
         s === 'approved'  ? 'bg-purple-100 dark:bg-purple-900/40 text-purple-700 dark:text-purple-400' :
         s === 'pending'   ? 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400' :
         'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-400'
}
