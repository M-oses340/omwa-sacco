const INTASEND_SECRET = Deno.env.get('INTASEND_SECRET_KEY')!
const INTASEND_BASE = Deno.env.get('INTASEND_SANDBOX') === 'true'
  ? 'https://sandbox.intasend.com/api/v1'
  : 'https://payment.intasend.com/api/v1'

// Simple in-memory cache — refreshes on cold start
let cachedBanks: unknown[] | null = null

Deno.serve(async (_req) => {
  try {
    if (cachedBanks) {
      return json({ banks: cachedBanks })
    }

    const res = await fetch(`${INTASEND_BASE}/send-money/bank-codes/ke/`, {
      headers: {
        'X-IntaSend-Public-Key': Deno.env.get('INTASEND_PUBLISHABLE_KEY')!,
        'Content-Type': 'application/json',
      },
    })

    if (!res.ok) {
      const err = await res.json()
      console.error('[BANK-CODES] IntaSend error:', JSON.stringify(err))
      return json({ error: 'Failed to fetch bank codes' }, 500)
    }

    const data = await res.json()
    cachedBanks = data
    return json({ banks: data })
  } catch (e) {
    console.error('[BANK-CODES] Error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  })
}
