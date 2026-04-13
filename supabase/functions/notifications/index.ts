// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!  // Firebase legacy server key
const FCM_URL = 'https://fcm.googleapis.com/fcm/send'

const R = (d: unknown, s = 200) =>
  new Response(JSON.stringify(d), { status: s, headers: { 'Content-Type': 'application/json' } })

function getUserId(req: Request, body: any): string | null {
  const raw = req.headers.get('Authorization') ?? (body?.jwt ? `Bearer ${body.jwt}` : null)
  if (!raw?.startsWith('Bearer ')) return null
  try {
    const parts = raw.slice(7).split('.')
    if (parts.length !== 3) return null
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const pad = b64.length % 4 === 0 ? '' : '='.repeat(4 - b64.length % 4)
    const p = JSON.parse(atob(b64 + pad))
    if (p.role !== 'authenticated') return null
    if (p.exp && p.exp < Math.floor(Date.now() / 1000)) return null
    return p.sub ?? null
  } catch { return null }
}

const ADMIN_ROLES = ['admin', 'treasurer', 'chairman']

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  let body: any
  try { body = await req.json() } catch { return R({ error: 'Invalid JSON' }, 400) }

  const uid = getUserId(req, body)
  if (!uid) return R({ error: 'Unauthorized' }, 401)

  try {
    const { data: member } = await db.from('members')
      .select('id, status, role, full_name').eq('user_id', uid).single()
    if (!member) return R({ error: 'Member not found' }, 404)
    if (member.status !== 'active') return R({ error: 'Account not active' }, 403)

    const isAdmin = ADMIN_ROLES.includes(member.role)

    switch (body.action) {
      case 'register_token':  return await registerToken(member.id, body)
      case 'get_preferences': return await getPreferences(member.id)
      case 'set_preferences': return await setPreferences(member.id, body)
      case 'get_inbox':       return await getInbox(member.id, body)
      case 'mark_read':       return await markRead(member.id, body)
      // Admin-only: send to specific member or broadcast
      case 'send':            return isAdmin ? await sendNotification(body) : R({ error: 'Forbidden' }, 403)
      case 'broadcast':       return isAdmin ? await broadcast(body) : R({ error: 'Forbidden' }, 403)
      default: return R({ error: 'Invalid action' }, 400)
    }
  } catch (e) {
    console.error('[NOTIFICATIONS]', (e as Error).message)
    return R({ error: (e as Error).message }, 500)
  }
})

// ── Token registration ────────────────────────────────────────────────────────
async function registerToken(memberId: string, body: any) {
  const { token, platform } = body
  if (!token) return R({ error: 'token required' }, 400)

  // Upsert device token
  const { error } = await db.from('device_tokens').upsert({
    member_id: memberId,
    token,
    platform: platform ?? 'android',
    updated_at: new Date().toISOString(),
  }, { onConflict: 'token' })

  if (error) throw new Error(error.message)
  return R({ success: true })
}

// ── Preferences ───────────────────────────────────────────────────────────────
async function getPreferences(memberId: string) {
  const { data } = await db.from('notification_preferences')
    .select('*').eq('member_id', memberId).maybeSingle()

  // Return defaults if not set
  return R({
    data: data ?? {
      member_id: memberId,
      deposits: true,
      withdrawals: true,
      loan_updates: true,
      repayment_reminders: true,
      dividends: true,
      system_alerts: true,
    }
  })
}

async function setPreferences(memberId: string, body: any) {
  const prefs = {
    member_id: memberId,
    deposits: body.deposits ?? true,
    withdrawals: body.withdrawals ?? true,
    loan_updates: body.loan_updates ?? true,
    repayment_reminders: body.repayment_reminders ?? true,
    dividends: body.dividends ?? true,
    system_alerts: body.system_alerts ?? true,
    updated_at: new Date().toISOString(),
  }
  const { error } = await db.from('notification_preferences')
    .upsert(prefs, { onConflict: 'member_id' })
  if (error) throw new Error(error.message)
  return R({ success: true })
}

// ── Inbox ─────────────────────────────────────────────────────────────────────
async function getInbox(memberId: string, body: any) {
  const limit = body.limit ?? 30
  const { data, error } = await db.from('notifications')
    .select('*').eq('member_id', memberId)
    .order('created_at', { ascending: false }).limit(limit)
  if (error) throw new Error(error.message)
  const unread = (data ?? []).filter((n: any) => !n.read_at).length
  return R({ data: data ?? [], unread, count: (data ?? []).length })
}

async function markRead(memberId: string, body: any) {
  const { notification_id, all } = body
  if (all) {
    await db.from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('member_id', memberId).is('read_at', null)
  } else if (notification_id) {
    await db.from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('id', notification_id).eq('member_id', memberId)
  }
  return R({ success: true })
}

// ── Core send logic ───────────────────────────────────────────────────────────
async function pushToMember(memberId: string, title: string, body: string, data?: Record<string, string>) {
  // Get device tokens
  const { data: tokens } = await db.from('device_tokens')
    .select('token').eq('member_id', memberId)
  if (!tokens?.length) return

  // Save to inbox
  await db.from('notifications').insert({
    member_id: memberId, title, body,
    data: data ?? {}, created_at: new Date().toISOString(),
  })

  // Send FCM push to all devices
  const sends = tokens.map((t: any) =>
    fetch(FCM_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        to: t.token,
        notification: { title, body, sound: 'default' },
        data: data ?? {},
        priority: 'high',
      }),
    }).then(r => r.json()).catch(e => console.error('[FCM]', e.message))
  )
  await Promise.allSettled(sends)
}

async function pushToTopic(topic: string, title: string, body: string, data?: Record<string, string>) {
  await fetch(FCM_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      to: `/topics/${topic}`,
      notification: { title, body, sound: 'default' },
      data: data ?? {},
      priority: 'high',
    }),
  })
}

// ── Admin: send to member ─────────────────────────────────────────────────────
async function sendNotification(body: any) {
  const { member_id, title, message, data } = body
  if (!member_id || !title || !message) return R({ error: 'member_id, title, message required' }, 400)
  await pushToMember(member_id, title, message, data)
  return R({ success: true })
}

// ── Admin: broadcast to all ───────────────────────────────────────────────────
async function broadcast(body: any) {
  const { title, message, data } = body
  if (!title || !message) return R({ error: 'title and message required' }, 400)

  // Save to all active members' inboxes
  const { data: members } = await db.from('members').select('id').eq('status', 'active')
  if (members?.length) {
    const inserts = members.map((m: any) => ({
      member_id: m.id, title, body: message,
      data: data ?? {}, created_at: new Date().toISOString(),
    }))
    await db.from('notifications').insert(inserts)
  }

  // FCM topic broadcast
  await pushToTopic('all_members', title, message, data)
  return R({ success: true, sent_to: members?.length ?? 0 })
}

// ── Exported helper — called by other functions ───────────────────────────────
// Usage: import { notify } from '../notifications/notify.ts'
export async function notify(
  memberId: string,
  type: 'deposit' | 'withdrawal' | 'loan_update' | 'repayment_reminder' | 'dividend' | 'system',
  title: string,
  message: string,
  data?: Record<string, string>
) {
  try {
    // Check preferences
    const { data: prefs } = await db.from('notification_preferences')
      .select('*').eq('member_id', memberId).maybeSingle()

    const prefKey: Record<string, string> = {
      deposit: 'deposits', withdrawal: 'withdrawals',
      loan_update: 'loan_updates', repayment_reminder: 'repayment_reminders',
      dividend: 'dividends', system: 'system_alerts',
    }
    const key = prefKey[type]
    if (prefs && key && prefs[key] === false) return // user opted out

    await pushToMember(memberId, title, message, data)
  } catch (e) {
    console.error('[NOTIFY]', (e as Error).message)
  }
}
