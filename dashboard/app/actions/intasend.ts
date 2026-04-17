'use server'

export async function getIntaSendBalance(): Promise<number | null> {
  try {
    const IS = process.env.INTASEND_SECRET_KEY
    const sandbox = process.env.INTASEND_SANDBOX === 'true'
    const base = sandbox ? 'https://sandbox.intasend.com/api/v1' : 'https://payment.intasend.com/api/v1'
    if (!IS) return null
    const res = await fetch(`${base}/wallets/`, {
      headers: { 'Authorization': `Bearer ${IS}`, 'Content-Type': 'application/json' },
      cache: 'no-store',
    })
    if (!res.ok) return null
    const data = await res.json()
    // Sum all KES wallets
    const wallets: any[] = data.results ?? data ?? []
    const total = wallets
      .filter((w: any) => w.currency === 'KES')
      .reduce((sum: number, w: any) => sum + parseFloat(w.available_balance ?? w.balance ?? '0'), 0)
    return total
  } catch {
    return null
  }
}
