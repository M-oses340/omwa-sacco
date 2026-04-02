import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { jsonResponse as json } from '../_shared/auth.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req: Request) => {
  try {
    const { email } = await req.json()
    if (!email) return json({ error: 'Email required' }, 400)

    const { error } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email,
    })

    if (error) {
      console.error('[OTP]', error.message)
      return json({ error: error.message }, 500)
    }

    return json({ success: true })
  } catch (e) {
    console.error('[OTP]', (e as Error).message)
    return json({ error: (e as Error).message }, 500)
  }
})
