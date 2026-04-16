'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

interface Props {
  member: any
  onClose: () => void
}

export default function MemberDetail({ member, onClose }: Props) {
  const [bosa, setBosa] = useState<any>(null)
  const [fosa, setFosa] = useState<any>(null)
  const [loans, setLoans] = useState<any[]>([])
  const [txs, setTxs] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState<'accounts' | 'loans' | 'transactions'>('accounts')

  useEffect(() => {
    async function load() {
      const [b, f, l, t] = await Promise.all([
        supabase.from('bosa_accounts').select('*').eq('member_id', member.id).maybeSingle(),
        supabase.from('fosa_accounts').select('*').eq('member_id', member.id).maybeSingle(),
        supabase.from('loans').select('*').eq('member_id', member.id).order('created_at', { ascending: false }),
        supabase.from('transactions').select('*').eq('member_id', member.id)
          .order('created_at', { ascending: false }).limit(50),
      ])
      setBosa(b.data)
      setFosa(f.data)
      setLoans(l.data ?? [])
      setTxs(t.data ?? [])
      setLoading(false)
    }
    load()
  }, [member.id])

  return (
    <div className="fixed inset-0 bg-black/40 z-50 flex items-start justify-end" onClick={onClose}>
      <div className="bg-white h-full w-full max-w-2xl shadow-2xl overflow-y-auto"
        onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b sticky top-0 bg-white z-10">
          <div>
            <h2 className="font-semibold text-lg">{member.full_name}</h2>
            <p className="text-xs text-gray-400 font-mono">{member.member_number} · {member.phone_number}</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-700 text-xl leading-none">✕</button>
        </div>

        {loading ? (
          <div className="p-6 text-gray-400 text-sm">Loading...</div>
        ) : (
          <div className="p-6">
            {/* Status badges */}
            <div className="flex gap-2 mb-5">
              <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                member.status === 'active' ? 'bg-green-100 text-green-700' :
                member.status === 'pending' ? 'bg-yellow-100 text-yellow-700' :
                'bg-red-100 text-red-700'}`}>{member.status}</span>
              <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-700 capitalize">{member.role}</span>
              <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
                Joined {member.created_at?.split('T')[0]}
              </span>
            </div>

            {/* Tabs */}
            <div className="flex gap-1 mb-5 border-b">
              {(['accounts', 'loans', 'transactions'] as const).map(t => (
                <button key={t} onClick={() => setTab(t)}
                  className={`px-4 py-2 text-sm font-medium capitalize border-b-2 transition-colors -mb-px
                    ${tab === t ? 'border-green-600 text-green-700' : 'border-transparent text-gray-500 hover:text-gray-700'}`}>
                  {t}
                </button>
              ))}
            </div>

            {/* Accounts tab */}
            {tab === 'accounts' && (
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-blue-50 rounded-xl p-4 border border-blue-100">
                  <p className="text-xs text-blue-500 font-medium mb-2">BOSA Account</p>
                  {bosa ? <>
                    <p className="font-mono text-xs text-gray-500 mb-3">{bosa.account_number}</p>
                    <div className="space-y-1.5">
                      <Row label="Savings" value={fmt(bosa.savings_balance)} />
                      <Row label="Shares" value={fmt(bosa.shares_balance)} />
                      <Row label="Deposits" value={fmt(bosa.deposit_balance)} />
                    </div>
                  </> : <p className="text-xs text-gray-400">No BOSA account</p>}
                </div>
                <div className="bg-green-50 rounded-xl p-4 border border-green-100">
                  <p className="text-xs text-green-600 font-medium mb-2">FOSA Account</p>
                  {fosa ? <>
                    <p className="font-mono text-xs text-gray-500 mb-3">{fosa.account_number}</p>
                    <div className="space-y-1.5">
                      <Row label="Balance" value={fmt(fosa.balance)} />
                      <Row label="Salary" value={fmt(fosa.salary_amount)} />
                    </div>
                  </> : <p className="text-xs text-gray-400">No FOSA account</p>}
                </div>
              </div>
            )}

            {/* Loans tab */}
            {tab === 'loans' && (
              <div className="space-y-3">
                {loans.length === 0 && <p className="text-gray-400 text-sm">No loans</p>}
                {loans.map(l => (
                  <div key={l.id} className="border rounded-xl p-4">
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-mono text-xs text-gray-500">{l.loan_number}</span>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${statusColor(l.status)}`}>{l.status}</span>
                    </div>
                    <p className="font-medium capitalize text-sm mb-2">{l.loan_type?.replace(/_/g, ' ')}</p>
                    <div className="grid grid-cols-3 gap-2 text-xs">
                      <div><p className="text-gray-400">Principal</p><p className="font-medium">{fmt(l.principal)}</p></div>
                      <div><p className="text-gray-400">Outstanding</p><p className="font-medium">{fmt(l.outstanding_balance)}</p></div>
                      <div><p className="text-gray-400">Monthly</p><p className="font-medium">{fmt(l.monthly_repayment)}</p></div>
                    </div>
                    {l.due_date && <p className="text-xs text-gray-400 mt-2">Due: {l.due_date}</p>}
                  </div>
                ))}
              </div>
            )}

            {/* Transactions tab */}
            {tab === 'transactions' && (
              <div className="space-y-1">
                {txs.length === 0 && <p className="text-gray-400 text-sm">No transactions</p>}
                {txs.map(t => (
                  <div key={t.id} className="flex items-center justify-between py-2.5 border-b last:border-0">
                    <div>
                      <p className="text-sm capitalize">{t.transaction_type?.replace(/_/g, ' ')}</p>
                      <p className="text-xs text-gray-400">{t.created_at?.split('T')[0]} · {t.reference}</p>
                    </div>
                    <div className="text-right">
                      <p className={`text-sm font-semibold ${
                        ['deposit', 'loan_disbursement', 'dividend'].includes(t.transaction_type)
                          ? 'text-green-600' : 'text-red-500'}`}>
                        {['deposit', 'loan_disbursement', 'dividend'].includes(t.transaction_type) ? '+' : '-'}
                        {fmt(t.amount)}
                      </p>
                      <span className={`text-xs ${
                        t.status === 'completed' ? 'text-green-500' :
                        t.status === 'pending' ? 'text-yellow-500' : 'text-red-400'}`}>{t.status}</span>
                    </div>
                  </div>
                ))}
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
  return s === 'disbursed' ? 'bg-blue-100 text-blue-700' :
         s === 'repaid'    ? 'bg-green-100 text-green-700' :
         s === 'approved'  ? 'bg-purple-100 text-purple-700' :
         s === 'pending'   ? 'bg-yellow-100 text-yellow-700' :
         'bg-red-100 text-red-700'
}
