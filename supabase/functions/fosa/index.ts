// deno-lint-ignore-file no-explicit-any
import { createRemoteJWKSet, jwtVerify } from 'https://esm.sh/jose@5';
const JWKS = createRemoteJWKSet(new URL(`${Deno.env.get('SUPABASE_URL')}/auth/v1/.well-known/jwks.json`));
async function getUid(authHeader) {
  try {
    if (!authHeader?.startsWith('Bearer ')) return null;
    const token = authHeader.slice(7);
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `${Deno.env.get('SUPABASE_URL')}/auth/v1`,
      audience: 'authenticated'
    });
    return payload.sub ?? null;
  } catch (e) {
    console.error('[F] JWT verify error:', e.message);
    return null;
  }
}
Deno.serve(async (req)=>{
  const R = (d, s = 200)=>new Response(JSON.stringify(d), {
      status: s,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  // Try Authorization header first, then body.jwt
  let token = req.headers.get('Authorization');
  let body;
  try {
    body = JSON.parse(await req.text());
  } catch  {
    return R({
      error: 'bad json'
    }, 400);
  }
  // If Authorization is anon key, use body.jwt instead
  if (!token || token.includes('role":"anon')) {
    token = body?.jwt ? `Bearer ${body.jwt}` : null;
  }
  const u = await getUid(token);
  console.log('[F] action:', body?.action, 'uid:', u);
  if (!u) return R({
    error: 'Unauthorized'
  }, 401);
  try {
    const B = Deno.env.get('SUPABASE_URL');
    const K = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const H = {
      'apikey': K,
      'Authorization': `Bearer ${K}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    };
    const g = async (t, q)=>{
      const r = await fetch(`${B}/rest/v1/${t}?${q}`, {
        headers: H
      });
      if (!r.ok) throw new Error(await r.text());
      return r.json();
    };
    const p = async (t, b)=>{
      const r = await fetch(`${B}/rest/v1/${t}`, {
        method: 'POST',
        headers: H,
        body: JSON.stringify(b)
      });
      if (!r.ok) throw new Error(await r.text());
      const d = await r.json();
      return Array.isArray(d) ? d[0] : d;
    };
    const x = async (t, q, b)=>{
      const r = await fetch(`${B}/rest/v1/${t}?${q}`, {
        method: 'PATCH',
        headers: {
          ...H,
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify(b)
      });
      if (!r.ok) throw new Error(await r.text());
    };
    if (body.action === 'ping') return R({
      ok: true,
      uid: u
    });
    const ms = await g('members', `user_id=eq.${u}&select=id,full_name,email,phone_number,status&limit=1`);
    const m = ms[0];
    if (!m) return R({
      error: 'Member not found'
    }, 404);
    if (m.status !== 'active') return R({
      error: 'Account not active'
    }, 403);
    const fs = await g('fosa_accounts', `member_id=eq.${m.id}&select=id,account_number,balance&limit=1`);
    const f = fs[0];
    if (!f) return R({
      error: 'FOSA not found'
    }, 404);
    const IS = Deno.env.get('INTASEND_SECRET_KEY');
    const IP = Deno.env.get('INTASEND_PUBLISHABLE_KEY') ?? Deno.env.get('INTASEND_PUBLIC_KEY') ?? '';
    const IB = Deno.env.get('INTASEND_SANDBOX') === 'true' ? 'https://sandbox.intasend.com/api/v1' : 'https://payment.intasend.com/api/v1';
    if (body.action === 'deposit_card') {
      const { amount } = body;
      if (!amount || amount < 10) return R({
        error: 'Min KES 10'
      });
      const ref = `DEP-${Date.now()}`;
      const tx = await p('transactions', {
        member_id: m.id,
        account_type: 'fosa',
        transaction_type: 'deposit',
        amount,
        balance_before: f.balance,
        reference: ref,
        description: 'FOSA deposit via IntaSend',
        status: 'pending'
      });
      if (!tx?.id) return R({
        error: 'TX failed'
      }, 500);
      const np = (m.full_name ?? '').split(' ');
      const cr = await fetch(`${IB}/checkout/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${IS}`
        },
        body: JSON.stringify({
          public_key: IP,
          amount,
          currency: 'KES',
          api_ref: ref,
          email: m.email ?? '',
          first_name: np[0] ?? '',
          last_name: np.slice(1).join(' ') ?? '',
          phone_number: m.phone_number ?? '',
          redirect_url: 'https://omwasacco.app/payment/callback'
        })
      });
      const cd = await cr.json();
      console.log('[F] checkout', cr.status, JSON.stringify(cd));
      if (!cr.ok || !cd.url) {
        await x('transactions', `id=eq.${tx.id}`, {
          status: 'failed'
        });
        return R({
          error: cd?.errors?.[0]?.detail ?? cd?.detail ?? cd?.message ?? `IS ${cr.status}`
        }, 500);
      }
      return R({
        success: true,
        checkout_url: cd.url,
        transaction_id: tx.id
      });
    }
    if (body.action === 'withdraw') {
      const { amount } = body;
      if (!amount || amount < 100) return R({
        error: 'Min KES 100'
      });
      const bal = parseFloat(f.balance);
      if (amount > bal) return R({
        error: `Insufficient. Available: KES ${bal.toFixed(2)}`
      });
      const ph = m.phone_number;
      const nm = ph.startsWith('+') ? ph.slice(1) : ph.startsWith('0') ? `254${ph.slice(1)}` : ph;
      const wr = await fetch(`${IB}/send-money/initiate/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${IS}`
        },
        body: JSON.stringify({
          currency: 'KES',
          provider: 'MPESA-B2C',
          requires_approval: 'NO',
          transactions: [
            {
              name: m.full_name,
              account: nm,
              amount: amount.toString(),
              narrative: 'FOSA withdrawal'
            }
          ]
        })
      });
      const wd = await wr.json();
      if (!wr.ok) return R({
        error: wd?.errors?.[0]?.detail ?? 'Withdrawal failed'
      });
      const nb = bal - amount;
      await x('fosa_accounts', `id=eq.${f.id}`, {
        balance: nb,
        updated_at: new Date().toISOString()
      });
      await p('transactions', {
        member_id: m.id,
        account_type: 'fosa',
        transaction_type: 'withdrawal',
        amount,
        balance_before: bal,
        balance_after: nb,
        reference: `WDR-${Date.now()}`,
        description: `Withdrawal to ${ph}`,
        status: 'pending'
      });
      return R({
        success: true
      });
    }
    return R({
      error: 'Invalid action'
    });
  } catch (e) {
    console.error('[F]', e.message);
    return R({
      error: e.message
    }, 500);
  }
});
