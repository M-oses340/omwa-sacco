// deno-lint-ignore-file no-explicit-any

Deno.serve(async (req: Request) => {
  // All env vars read inside handler — never at module level
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY')!
  const INTASEND_PUB = Deno.env.get('INTASEND_PUBLISHABLE_KEY') ?? Deno.env.get('INTASEND_PUBLIC_KEY') ?? ''
  const INTASEND_BASE = Deno.env.get('INTASEND_SANDBOX') === 'true'
    ? 'https://sandbox.intasend.com/api/v1'
    : 'https://payment.intasend.com/api/v1'

  // ── JWT decode ──────────────────────────────────────────────────────────────
  function userId(): string | null {
    try {
      const h = req.headers.get('Authorization')
      if (!h?.startsWith('Bearer ')) return null
      const parts = h.split('.')
      if (parts.length !== 3) return null
      const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
      const pad = b64.length % 4 === 0 ? '' : '='.repeat(4 - b64.length % 4)
      const d = JSON.parse(new TextDecoder().decode(
        Uint8Array.from(atob(b64 + pad), (c) => c.charCodeAt(0))
      ))
      if (d.role !== 'authenticated') return null
      if (d.exp && d.exp < Math.floor(Date.now() / 1000)) return null
      return d.sub ?? null
    } catch { return null }
  }

  const uid = userId()
  if (!uid) return res({ error: 'Unauthorized' }, 401)

  // ── DB helper ───────────────────────────────────────────────────────────────
  async function db(method: string, path: string, body?: object): Promise<any> {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
      method,
      headers: {
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: body ? JSON.stringify(body) : undefined,
    })
    const text = await r.text()
    if (!r.ok) throw new Error(text)
    return text ? JSON.parse(text) : null
  }

  // ── IntaSend helper ─────────────────────────────────────────────────────────
  async function is(path: string, body: object) {
    const r = await fetch(`${INTASEND_BASE}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${INTASEND_SECRET}` },
      body: JSON.stringify(body),
    })
    const data = await r.json()
    return { ok: r.ok, status: r.status, data }
  }

  // ── Member + FOSA lookup ────────────────────────────────────────────────────
  async function getMF() {
    const ms = await db('GET', `members?user_id=eq.${uid}&select=id,full_name,email,phone_number,status&limit=1`)
    const m = Array.isArray(ms) ? ms[0] : null
    if (!m) throw new Error('Member not found')
    if (m.status !== 'active') throw new Error('Account not active')
    const fs = await db('GET', `fosa_accounts?member_id=eq.${m.id}&select=id,account_number,balance&limit=1`)
    const f = Array.isArray(fs) ? fs[0] : null
    if (!f) throw new Error('FOSA account not found')
    return { m, f }
  }

  try {
    const body = await req.json()
    console.log('[FOSA] action:', body.action, 'uid:', uid)

    if (body.action === 'deposit_card') {
      const { amount } = body
      if (!amount || amount < 10) return res({ error: 'Minimum deposit is KES 10' }, 400)
      const { m, f } = await getMF()
      const ref = `DEP-${Date.now()}`
      const txArr = await db('POST', 'transactions', {
        member_id: m.id, account_type: 'fosa', transaction_type: 'deposit',
        amount, balance_before: f.balance, reference: ref,
        description: 'FOSA deposit via IntaSend', status: 'pending',
      })
      const tx = Array.isArray(txArr) ? txArr[0] : txArr
      if (!tx?.id) return res({ error: 'Failed to create transaction' }, 500)
      const np = (m.full_name ?? '').split(' ')
      const { ok, status, data } = await is('/checkout/', {
        public_key: INTASEND_PUB, amount, currency: 'KES', api_ref: ref,
        email: m.email ?? '', first_name: np[0] ?? '',
        last_name: np.slice(1).join(' ') ?? '',
        phone_number: m.phone_number ?? '',
        redirect_url: 'https://omwasacco.app/payment/callback',
      })
      console.log('[FOSA] checkout:', status, JSON.stringify(data))
      if (!ok || !data.url) {
        await db('PATCH', `transactions?id=eq.${tx.id}`, { status: 'failed' })
        return res({ error: data?.errors?.[0]?.detail ?? data?.detail ?? data?.message ?? `IntaSend ${status}` }, 500)
      }
      return res({ success: true, checkout_url: data.url, transaction_id: tx.id })
    }

    if (body.action === 'withdraw') {
      const { amount } = body
      if (!amount || amount < 100) return res({ error: 'Minimum withdrawal is KES 100' }, 400)
      const { m, f } = await getMF()
      const bal = parseFloat(f.balance)
      if (amount > bal) return res({ error: `Insufficient balance. Available: KES ${bal.toFixed(2)}` }, 400)
      const ph = m.phone_number
      const norm = ph.startsWith('+') ? ph.slice(1) : ph.startsWith('0') ? `254${ph.slice(1)}` : ph
      const { ok, data } = await is('/send-money/initiate/', {
        currency: 'KES', provider: 'MPESA-B2C', requires_approval: 'NO',
        transactions: [{ name: m.full_name, account: norm, amount: amount.toString(), narrative: 'FOSA withdrawal - Omwa Sacco' }],
      })
      if (!ok) return res({ error: data?.errors?.[0]?.detail ?? 'Withdrawal failed' }, 400)
      const nb = bal - amount
      await db('PATCH', `fosa_accounts?id=eq.${f.id}`, { balance: nb, updated_at: new Date().toISOString() })
      await db('POST', 'transactions', {
        member_id: m.id, account_type: 'fosa', transaction_type: 'withdrawal',
        amount, balance_before: bal, balance_after: nb,
        reference: `WDR-${Date.now()}`, description: `M-Pesa withdrawal to ${ph}`, status: 'pending',
      })
      return res({ success: true })
    }

    return res({ error: 'Invalid action' }, 400)
  } catch (e) {
    console.error('[FOSA] error:', (e as Error).message)
    return res({ error: (e as Error).message }, 500)
  }
})

function res(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status, headers: { 'Content-Type': 'application/json' },
  })
}
