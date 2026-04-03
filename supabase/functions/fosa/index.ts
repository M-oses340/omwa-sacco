Deno.serve(async (req) => {
  function r(data, status = 200) {
    return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } })
  }
  function uid() {
    try {
      const h = req.headers.get('Authorization')
      if (!h?.startsWith('Bearer ')) return null
      const p = h.split('.')
      if (p.length !== 3) return null
      const b = p[1].replace(/-/g,'+').replace(/_/g,'/')
      const pad = b.length%4===0?'':'='.repeat(4-b.length%4)
      const d = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b+pad),c=>c.charCodeAt(0))))
      if (d.role!=='authenticated') return null
      if (d.exp && d.exp<Math.floor(Date.now()/1000)) return null
      return d.sub??null
    } catch { return null }
  }
  const u = uid()
  if (!u) return r({error:'Unauthorized'},401)
  const SU = Deno.env.get('SUPABASE_URL')??''
  const SK = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??''
  const IS = Deno.env.get('INTASEND_SECRET_KEY')??''
  const IP = Deno.env.get('INTASEND_PUBLISHABLE_KEY')??''
  const IB = Deno.env.get('INTASEND_SANDBOX')==='true'?'https://sandbox.intasend.com/api/v1':'https://payment.intasend.com/api/v1'
  async function db(m,p,b) {
    const res=await fetch(`${SU}/rest/v1/${p}`,{method:m,headers:{'apikey':SK,'Authorization':`Bearer ${SK}`,'Content-Type':'application/json','Prefer':'return=representation'},body:b?JSON.stringify(b):undefined})
    const t=await res.text()
    if(!res.ok) throw new Error(t)
    return t?JSON.parse(t):null
  }
  async function is(p,b) {
    const res=await fetch(`${IB}${p}`,{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${IS}`},body:JSON.stringify(b)})
    const d=await res.json()
    return {ok:res.ok,status:res.status,data:d}
  }
  async function mf() {
    const ms=await db('GET',`members?user_id=eq.${u}&select=id,full_name,email,phone_number,status&limit=1`)
    const m=ms?.[0]; if(!m) throw new Error('Member not found')
    if(m.status!=='active') throw new Error('Account not active')
    const fs=await db('GET',`fosa_accounts?member_id=eq.${m.id}&select=id,account_number,balance&limit=1`)
    const f=fs?.[0]; if(!f) throw new Error('FOSA account not found')
    return {m,f}
  }
  try {
    const body=await req.json()
    console.log('[FOSA]',body.action,u)
    if(body.action==='deposit_card') {
      const {amount}=body
      if(!amount||amount<10) return r({error:'Minimum deposit is KES 10'},400)
      const {m,f}=await mf()
      const ref=`DEP-${Date.now()}`
      const ta=await db('POST','transactions',{member_id:m.id,account_type:'fosa',transaction_type:'deposit',amount,balance_before:f.balance,reference:ref,description:'FOSA deposit via IntaSend',status:'pending'})
      const tx=Array.isArray(ta)?ta[0]:ta
      if(!tx?.id) return r({error:'Failed to create transaction'},500)
      const np=(m.full_name??'').split(' ')
      const {ok,status,data}=await is('/checkout/',{public_key:IP,amount,currency:'KES',api_ref:ref,email:m.email??'',first_name:np[0]??'',last_name:np.slice(1).join(' ')??'',phone_number:m.phone_number??'',redirect_url:'https://omwasacco.app/payment/callback'})
      console.log('[FOSA] checkout:',status,JSON.stringify(data))
      if(!ok||!data.url) { await db('PATCH',`transactions?id=eq.${tx.id}`,{status:'failed'}); return r({error:data?.errors?.[0]?.detail??data?.detail??data?.message??`IntaSend ${status}`},500) }
      return r({success:true,checkout_url:data.url,transaction_id:tx.id})
    }
    if(body.action==='withdraw') {
      const {amount}=body
      if(!amount||amount<100) return r({error:'Minimum withdrawal is KES 100'},400)
      const {m,f}=await mf()
      const bal=parseFloat(f.balance)
      if(amount>bal) return r({error:`Insufficient balance. Available: KES ${bal.toFixed(2)}`},400)
      const ph=m.phone_number
      const norm=ph.startsWith('+')?ph.slice(1):ph.startsWith('0')?`254${ph.slice(1)}`:ph
      const {ok,data}=await is('/send-money/initiate/',{currency:'KES',provider:'MPESA-B2C',requires_approval:'NO',transactions:[{name:m.full_name,account:norm,amount:amount.toString(),narrative:'FOSA withdrawal - Omwa Sacco'}]})
      if(!ok) return r({error:data?.errors?.[0]?.detail??'Withdrawal failed'},400)
      const nb=bal-amount
      await db('PATCH',`fosa_accounts?id=eq.${f.id}`,{balance:nb,updated_at:new Date().toISOString()})
      await db('POST','transactions',{member_id:m.id,account_type:'fosa',transaction_type:'withdrawal',amount,balance_before:bal,balance_after:nb,reference:`WDR-${Date.now()}`,description:`M-Pesa withdrawal to ${ph}`,status:'pending'})
      return r({success:true})
    }
    return r({error:'Invalid action'},400)
  } catch(e) {
    console.error('[FOSA] error:',e.message)
    return r({error:e.message},500)
  }
})
