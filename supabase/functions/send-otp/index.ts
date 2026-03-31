import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  try {
    const { phone_number, member_id, device_id } = await req.json()

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString()
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000) // 10 minutes

    // Store OTP (you can use a separate otp_tokens table or Supabase Auth OTP)
    await supabase.from('member_devices').update({
      status: 'pending',
      otp_verified: false,
    }).eq('member_id', member_id).eq('device_id', device_id)

    // TODO: Send OTP via Africa's Talking or Twilio SMS
    console.log(`OTP for ${phone_number}: ${otp}`)

    return new Response(JSON.stringify({ success: true, expires_at: expiresAt }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    const err = error as Error
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
