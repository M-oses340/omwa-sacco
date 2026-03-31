import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import IntaSend from 'npm:intasend-node'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Unauthorized' }, 401)

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return json({ error: 'Unauthorized' }, 401)

    const { amount } = await req.json()
    if (!amount || amount < 10) {
      return json({ error: 'Minimum deposit is KES 10' }, 400)
    }

    const { data: member } = await supabase
      .from('members')
      .select('id, full_name, email, phone_number')
      .eq('user_id', user.id)
      .single()

    if (!member) return json({ error: 'Member not found' }, 404)

    const { data: fosa } = await supabase
      .from('fosa_accounts')
      .select('id, account_number')
      .eq('member_id', member.id)
      .single()

    if (!fosa) return json({ error: 'FOSA account not found' }, 404)

    const reference = `DEP-${Date.now()}`

    const { data: tx } = await supabase
      .from('transactions')
      .insert({
        member_id: member.id,
        account_type: 'fosa',
        transaction_type: 'deposit',
        amount,
        reference,
        description: 'FOSA deposit via M-Pesa/Card',
        status: 'pending',
      })
      .select('id')
      .single()

    const isSandbox = Deno.env.get('INTASEND_SANDBOX') === 'true'
    const intasend = new IntaSend(
      Deno.env.get('INTASEND_PUBLISHABLE_KEY')!,
      Deno.env.get('INTASEND_SECRET_KEY')!,
      isSandbox
    )

    const collection = intasend.collection()

    console.log('[CHECKOUT] Initiating checkout for KES', amount)

    const response = await collection.charge({
      first_name: member.full_name.split(' ')[0],
      last_name: member.full_name.split(' ').slice(1).join(' ') || '',
      email: member.email ?? '',
      host: 'https://omwasacco.app',
      amount,
      currency: 'KES',
      api_ref: reference,
      redirect_url: 'https://omwasacco.app/payment/callback',
    })

    console.log('[CHECKOUT] IntaSend response:', JSON.stringify(response))

    return json({
      success: true,
      checkout_url: response.url,
      transaction_id: tx!.id,
    })
  } catch (e) {
    console.error('[CHECKOUT] Error:', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
