// deno-lint-ignore-file no-explicit-any
import { createRemoteJWKSet, jwtVerify } from 'https://esm.sh/jose@5'

async function getUid(req: Request, bodyJwt?: string): Promise<string | null> {
  const url = Deno.env.get('SUPABASE_URL')!
  const JWKS = createRemoteJWKSet(new URL(`${url}/auth/v1/.well-known/jwks.json`))
  let token: string | null = null
  const h = req.headers.get('Authorization')
  if (h?.startsWith('Bearer ') && !h.includes('"role":"anon"')) {
    const t = h.slice(7)
    if (t.split('.').length === 3) token = t
  }
  if (!token && bodyJwt) token = bodyJwt
  if (!token) return null
  try {
    const { payload } = await jwtVerify(token, JWKS, { issuer: `${url}/auth/v1`, audience: 'authenticated' })
    return (payload.sub as string) ?? null
  } catch { return null }
}

Deno.serve(async (req: Request) => {
  const R = (d: any, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { 'Content-Type': 'application/json' } })
  let body: any
  try { body = JSON.parse(await req.text()) } catch { return R({ error: 'bad json' }, 400) }
  const u = await getUid(req, body?.jwt)
  if (!u) return R({ error: 'Unauthorized' }, 401)

  const B = Deno.env.get('SUPABASE_URL')!, K = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const IS = Deno.env.get('INTASEND_SECRET_KEY')!
  const IB = Deno.env.get('INTASEND_SANDBOX') === 'true' ? 'https://sandbox.intasend.com/api/v1' : 'https://payment.intasend.com/api/v1'
  const H = { 'apikey': K, 'Authorization': `Bearer ${K}`, 'Content-Type': 'application/json', 'Prefer': 'return=representation' }
  const g = async (t: string, q: string) => { const r = await fetch(`${B}/rest/v1/${t}?${q}`, { headers: H }); if (!r.ok) throw new Error(await r.text()); return r.json() }
  const p = async (t: string, b: any) => { const r = await fetch(`${B}/rest/v1/${t}`, { method: 'POST', headers: H, body: JSON.stringify(b) }); if (!r.ok) throw new Error(await r.text()); const d = await r.json(); return Array.isArray(d) ? d[0] : d }
  const x = async (t: string, q: string, b: any) => { const r = await fetch(`${B}/rest/v1/${t}?${q}`, { method: 'PATCH', headers: { ...H, 'Prefer': 'return=minimal' }, body: JSON.stringify(b) }); if (!r.ok) throw new Error(await r.text()) }

  try {
    const { type, amount } = body
    if (!amount || amount <= 0) return R({ error: 'Invalid amount' })

    const ms = await g('members', `user_id=eq.${u}&select=id,full_name,member_number&limit=1`)
    const m = ms[0]; if (!m) return R({ error: 'Member not found' }, 404)
    const fs = await g('fosa_accounts', `member_id=eq.${m.id}&select=id,balance&limit=1`)
    const f = fs[0]; if (!f) return R({ error: 'FOSA not found' }, 404)

    if (type === 'internal') {
      const { to_member_number, note } = body
      const tm = (await g('members', `member_number=eq.${to_member_number}&select=id,full_name&limit=1`))[0]
      if (!tm) return R({ error: `Member ${to_member_number} not found` }, 404)
      if (tm.id === m.id) return R({ error: 'Cannot transfer to yourself' })
      const bal = parseFloat(f.balance)
      if (amount > bal) return R({ error: `Insufficient balance. Available: KES ${bal.toFixed(2)}` })
      const tf = (await g('fosa_accounts', `member_id=eq.${tm.id}&select=id,balance&limit=1`))[0]
      if (!tf) return R({ error: 'Recipient FOSA not found' }, 404)
      const ref = `TRF-${Date.now()}`, nb = bal - amount, tb = parseFloat(tf.balance) + amount
      await x('fosa_accounts', `id=eq.${f.id}`, { balance: nb })
      await x('fosa_accounts', `id=eq.${tf.id}`, { balance: tb })
      await p('transactions', { member_id: m.id, account_type: 'fosa', transaction_type: 'transfer', amount, balance_before: bal, balance_after: nb, reference: ref, description: `Transfer to ${tm.full_name}${note ? ': ' + note : ''}`, status: 'completed' })
      await p('transactions', { member_id: tm.id, account_type: 'fosa', transaction_type: 'transfer', amount, balance_before: parseFloat(tf.balance), balance_after: tb, reference: `${ref}-IN`, description: `Transfer from ${m.full_name}${note ? ': ' + note : ''}`, status: 'completed' })
      return R({ success: true, message: `KES ${amount.toFixed(2)} transferred to ${tm.full_name}` })
    }

    if (type === 'external') {
      const { bank_code, account_number, account_name } = body
      const bal = parseFloat(f.balance)
      if (amount > bal) return R({ error: `Insufficient balance. Available: KES ${bal.toFixed(2)}` })
      const wr = await fetch(`${IB}/send-money/initiate/`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${IS}` }, body: JSON.stringify({ currency: 'KES', provider: 'PESALINK', requires_approval: 'NO', transactions: [{ name: account_name, account: account_number, bank_code, amount: amount.toString(), narrative: 'Bank transfer - Omwa Sacco' }] }) })
      const wd = await wr.json()
      if (!wr.ok) return R({ error: wd?.errors?.[0]?.detail ?? 'Bank transfer failed' })
      const nb = bal - amount
      await x('fosa_accounts', `id=eq.${f.id}`, { balance: nb })
      await p('transactions', { member_id: m.id, account_type: 'fosa', transaction_type: 'transfer', amount, balance_before: bal, balance_after: nb, reference: `EXT-${Date.now()}`, description: `Bank transfer to ${account_name}`, status: 'pending' })
      return R({ success: true })
    }

    return R({ error: 'Invalid transfer type' })
  } catch (e) {
    console.error('[T]', (e as Error).message)
    return R({ error: (e as Error).message }, 500)
  }
})
