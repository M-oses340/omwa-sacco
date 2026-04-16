'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

const TYPES = [
  { value: 'general',     label: 'General' },
  { value: 'loan_update', label: 'Loan Update' },
  { value: 'payment',     label: 'Payment' },
  { value: 'alert',       label: 'Alert' },
]

export default function Notifications() {
  const [members, setMembers] = useState<any[]>([])
  const [target, setTarget] = useState<'all' | 'specific'>('all')
  const [selectedId, setSelectedId] = useState('')
  const [type, setType] = useState('general')
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [sending, setSending] = useState(false)
  const [toast, setToast] = useState('')
  const [recent, setRecent] = useState<any[]>([])
  const [loadingRecent, setLoadingRecent] = useState(true)

  useEffect(() => {
    supabase.from('members').select('id, full_name, member_number').eq('status', 'active')
      .order('full_name').limit(300).then(({ data }) => setMembers(data ?? []))
    loadRecent()
  }, [])

  async function loadRecent() {
    setLoadingRecent(true)
    const { data } = await supabase.from('notifications')
      .select('id, title, body, type, is_read, created_at, members!notifications_member_id_fkey(full_name, member_number)')
      .order('created_at', { ascending: false })
      .limit(30)
    setRecent(data ?? [])
    setLoadingRecent(false)
  }

  async function send(e: React.FormEvent) {
    e.preventDefault()
    if (!title.trim() || !body.trim()) return
    setSending(true)

    try {
      if (target === 'all') {
        // Insert for all active members in batches
        const rows = members.map(m => ({
          member_id: m.id, type, title: title.trim(), body: body.trim(), is_read: false,
        }))
        // Supabase insert supports up to 1000 rows at once
        for (let i = 0; i < rows.length; i += 500) {
          await supabase.from('notifications').insert(rows.slice(i, i + 500))
        }
        showToast(`Sent to ${members.length} members`)
      } else {
        if (!selectedId) { showToast('Select a member'); setSending(false); return }
        await supabase.from('notifications').insert({
          member_id: selectedId, type, title: title.trim(), body: body.trim(), is_read: false,
        })
        showToast('Notification sent')
      }
      setTitle('')
      setBody('')
      loadRecent()
    } catch {
      showToast('Failed to send')
    }
    setSending(false)
  }

  function showToast(msg: string) {
    setToast(msg)
    setTimeout(() => setToast(''), 3000)
  }

  return (
    <div>
      <h2 className="text-xl font-semibold mb-5">Notifications</h2>

      {toast && (
        <div className="fixed top-4 right-4 bg-green-600 text-white text-sm px-4 py-2 rounded-lg shadow z-50">
          {toast}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Compose */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
          <h3 className="font-medium text-gray-700 mb-4">Send Notification</h3>
          <form onSubmit={send} className="flex flex-col gap-3">
            {/* Target */}
            <div className="flex gap-2">
              {(['all', 'specific'] as const).map(t => (
                <button type="button" key={t} onClick={() => setTarget(t)}
                  className={`flex-1 py-2 rounded-lg text-xs font-medium capitalize border transition-colors
                    ${target === t ? 'bg-green-600 text-white border-green-600' : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'}`}>
                  {t === 'all' ? `All Members (${members.length})` : 'Specific Member'}
                </button>
              ))}
            </div>

            {target === 'specific' && (
              <select value={selectedId} onChange={e => setSelectedId(e.target.value)} required
                className="border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
                <option value="">Select member...</option>
                {members.map(m => (
                  <option key={m.id} value={m.id}>{m.full_name} ({m.member_number})</option>
                ))}
              </select>
            )}

            <select value={type} onChange={e => setType(e.target.value)}
              className="border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
              {TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
            </select>

            <input required placeholder="Title" value={title} onChange={e => setTitle(e.target.value)}
              className="border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />

            <textarea required placeholder="Message body..." value={body} onChange={e => setBody(e.target.value)}
              rows={4}
              className="border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500 resize-none" />

            <button type="submit" disabled={sending}
              className="bg-green-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-green-700 disabled:opacity-50">
              {sending ? 'Sending...' : 'Send Notification'}
            </button>
          </form>
        </div>

        {/* Recent */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
          <h3 className="font-medium text-gray-700 mb-4">Recent Notifications</h3>
          {loadingRecent ? <p className="text-gray-400 text-sm">Loading...</p> : (
            <div className="space-y-3 max-h-[480px] overflow-y-auto pr-1">
              {recent.length === 0 && <p className="text-gray-400 text-sm">No notifications sent yet</p>}
              {recent.map(n => (
                <div key={n.id} className="border rounded-lg p-3">
                  <div className="flex items-start justify-between gap-2 mb-1">
                    <p className="text-sm font-medium leading-tight">{n.title}</p>
                    <span className={`shrink-0 px-1.5 py-0.5 rounded text-xs ${
                      n.type === 'alert' ? 'bg-red-100 text-red-600' :
                      n.type === 'loan_update' ? 'bg-blue-100 text-blue-600' :
                      n.type === 'payment' ? 'bg-green-100 text-green-600' :
                      'bg-gray-100 text-gray-500'}`}>{n.type}</span>
                  </div>
                  <p className="text-xs text-gray-500 mb-1.5 line-clamp-2">{n.body}</p>
                  <div className="flex items-center justify-between text-xs text-gray-400">
                    <span>{(n.members as any)?.full_name ?? 'All members'}</span>
                    <span>{n.created_at?.split('T')[0]}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
