// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } }
)

export async function notify(
  memberId: string,
  type: 'deposit' | 'withdrawal' | 'loan_update' | 'repayment_reminder' | 'dividend' | 'system',
  title: string,
  message: string,
  data?: Record<string, string>
) {
  try {
    const { data: prefs } = await db.from('notification_preferences')
      .select('*').eq('member_id', memberId).maybeSingle()

    const prefKey: Record<string, string> = {
      deposit: 'deposits', withdrawal: 'withdrawals',
      loan_update: 'loan_updates', repayment_reminder: 'repayment_reminders',
      dividend: 'dividends', system: 'system_alerts',
    }
    const key = prefKey[type]
    if (prefs && key && prefs[key] === false) return

    await db.from('notifications').insert({
      member_id: memberId, title, body: message,
      data: data ?? {}, created_at: new Date().toISOString(),
    })
  } catch (e) {
    console.error('[NOTIFY]', (e as Error).message)
  }
}
