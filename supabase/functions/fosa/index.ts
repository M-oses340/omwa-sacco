// deno-lint-ignore-file no-explicit-any

function jwtUserId(authHeader: string | null): string | null {
  try {
    if (!authHeader?.startsWith('Bearer ')) return null
    const parts = authHeader.split('.')
    if (parts.length !== 3) return null
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const pad = b64.length % 4 === 0 ? '' : '='.repeat(4 - b64.length % 4)
    const decoded = new TextDecoder().decode(
      Uint8Array.from(atob(b64 + pad), (c) => c.charCodeAt(0))
    )
    const data = JSON.parse(decoded)
    if (data.role !== 'authenticated') return null
    if (data.exp && data.exp < Math.floor(Date.now() / 1000)) return null
    return data.sub as string ?? null
  } catch { return null }
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status, headers: { 'Content-Type': 'application/json' },
  })
}

async function db(method: string, path: string, body?: object): Promise<any> {
  const url = Deno.env.get('SUPABASE_URL')!
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const res = await fetch(`${url}/rest/v1/${path}`, {
    method,
    headers: {
      'apikey': key,
      'Authorization': `Bearer ${key}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  const text = await res.text()
  if (!res.ok) throw new Error(text)
  return text ? JSON.parse(text) : null
}

const INTASEND_BASE = () => Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'

async function intasend(path: string, body: object): Promise<any> {
  const secret = Deno.env.get('INTASEND_SECRET_KEY')!
  const res = await fetch(`${INTASEND_BASE()}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${secret}` },
    body: JSON.stringify(body),
  })
  const data = await res.json()
  return { ok: res.ok, status: res.status, data }
}

Deno.serve(async (req: Request) => {
  const userId = jwtUserId(req.headers.get('Authorization'))
  if (!userId) return json({ error: 'Unauthorized' }, 401)

  try {
    const body = await req.json()
    console.log('[FOSA] action:', body.action, 'userId:', userId)

    switch (body.action) {
      case 'deposit_card':  return await depositCard(userId, body)
      case 'deposit_mpesa': return await depositMpesa(userId, body)
      case 'withdraw':      return await withdraw(userId, body)
      default:              return json({ error: 'Invalid action' }, 400)
    }
  } catch (e) {
    console.error('[FOSA] error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

async function getMemberFosa(userId: string) {
  const members = await db('GET', `members?user_id=eq.${userId}&select=id,full_name,email,phone_number,status&limit=1`)
  const member = Array.isArray(members) ? members[0] : null
  if (!member) throw new Error('Member not found')
  if (member.status !== 'active') throw new Error('Account not active')

  const fosas = await db('GET', `fosa_accounts?member_id=eq.${member.id}&select=id,account_number,balance&limit=1`)
  const fosa = Array.isArray(fosas) ? fosas[0] : null
  if (!fosa) throw new Error('FOSA account not found')

  return { member, fosa }
}

async function depositCard(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 10) return json({ error: 'Minimum deposit is KES 10' }, 400)

  const { member, fosa } = await getMemberFosa(userId)
  const reference = `DEP-${Date.now()}`

  const txArr = await db('POST', 'transactions', {
    member_id: member.id, account_type: 'fosa', transaction_type: 'deposit',
    amount, balance_before: fosa.balance, reference,
    description: 'FOSA deposit via IntaSend', status: 'pending',
  })
  const tx = Array.isArray(txArr) ? txArr[0] : txArr
  if (!tx?.id) return json({ error: 'Failed to create transaction' }, 500)

  const pub = Deno.env.get('INTASEND_PUBLISHABLE_KEY') ?? Deno.env.get('INTASEND_PUBLIC_KEY') ?? ''
  const nameParts = (member.full_name ?? '').split(' ')
  const { ok, status, data } = await intasend('/checkout/', {
    public_key: pub, amount, currency: 'KES', api_ref: reference,
    email: member.email ?? '', first_name: nameParts[0] ?? '',
    last_name: nameParts.slice(1).join(' ') ?? '',
    phone_number: member.phone_number ?? '',
    redirect_url: 'https://omwasacco.app/payment/callback',
  })

  console.log('[FOSA] checkout:', status, JSON.stringify(data))

  if (!ok || !data.url) {
    await db('PATCH', `transactions?id=eq.${tx.id}`, { status: 'failed' })
    const errMsg = data?.errors?.[0]?.detail ?? data?.detail ?? data?.message ?? `IntaSend ${status}`
    return json({ error: errMsg }, 500)
  }

  return json({ success: true, checkout_url: data.url, transaction_id: tx.id })
}

async function depositMpesa(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 10) return json({ error: 'Minimum deposit is KES 10' }, 400)

  const { member, fosa } = await getMemberFosa(userId)
  const txArr = await db('POST', 'transactions', {
    member_id: member.id, account_type: 'fosa', transaction_type: 'deposit',
    amount, balance_before: fosa.balance,
    description: 'FOSA deposit via M-Pesa STK Push', status: 'pending',
  })
  const tx = Array.isArray(txArr) ? txArr[0] : txArr
  if (!tx?.id) return json({ error: 'Failed to create transaction' }, 500)

  const phone = member.phone_number.startsWith('+') ? member.phone_number.slice(1)
    : member.phone_number.startsWith('0') ? `254${member.phone_number.slice(1)}`
    : member.phone_number

  const { ok, status, data } = await intasend('/payment/mpesa-stk-push/', {
    amount, phone_number: phone,
    api_ref: `${member.id}:fosa:${tx.id}`,
    narrative: `Omwa Sacco FOSA Deposit - ${fosa.account_number}`,
  })

  console.log('[FOSA] stk:', status, JSON.stringify(data))

  if (!ok) {
    await db('PATCH', `transactions?id=eq.${tx.id}`, { status: 'failed' })
    return json({ error: data?.detail ?? data?.message ?? 'STK push failed' }, 400)
  }

  if (data?.invoice?.invoice_id) {
    await db('PATCH', `transactions?id=eq.${tx.id}`, { intasend_ref: data.invoice.invoice_id })
  }
  return json({ success: true, message: 'M-Pesa prompt sent. Enter your PIN to complete.', transaction_id: tx.id })
}

async function withdraw(userId: string, body: any) {
  const { amount } = body
  if (!amount || amount < 100) return json({ error: 'Minimum withdrawal is KES 100' }, 400)

  const { member, fosa } = await getMemberFosa(userId)
  const balance = parseFloat(fosa.balance)
  if (amount > balance) return json({ error: `Insufficient balance. Available: KES ${balance.toFixed(2)}` }, 400)

  const phone = member.phone_number
  const normalised = phone.startsWith('+') ? phone.slice(1)
    : phone.startsWith('0') ? `254${phone.slice(1)}` : phone

  const { ok, data } = await intasend('/send-money/initiate/', {
    currency: 'KES', provider: 'MPESA-B2C', requires_approval: 'NO',
    transactions: [{ name: member.full_name, account: normalised, amount: amount.toString(), narrative: 'FOSA withdrawal - Omwa Sacco' }],
  })

  if (!ok) return json({ error: data?.errors?.[0]?.detail ?? 'Withdrawal failed' }, 400)

  const newBalance = balance - amount
  await db('PATCH', `fosa_accounts?id=eq.${fosa.id}`, { balance: newBalance, updated_at: new Date().toISOString() })
  await db('POST', 'transactions', {
    member_id: member.id, account_type: 'fosa', transaction_type: 'withdrawal',
    amount, balance_before: balance, balance_after: newBalance,
    reference: `WDR-${Date.now()}`, description: `M-Pesa withdrawal to ${phone}`, status: 'pending',
  })

  return json({ success: true })
}
