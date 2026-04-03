// Raw PostgREST helper — no @supabase/supabase-js, no session management

function headers() {
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  return {
    'apikey': key,
    'Authorization': `Bearer ${key}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  }
}

function baseUrl() {
  return Deno.env.get('SUPABASE_URL')!
}

// deno-lint-ignore no-explicit-any
export async function dbSelect(table: string, query: string): Promise<any[]> {
  const res = await fetch(`${baseUrl()}/rest/v1/${table}?${query}`, { headers: headers() })
  if (!res.ok) throw new Error(`DB select ${table}: ${await res.text()}`)
  return res.json()
}

// deno-lint-ignore no-explicit-any
export async function dbInsert(table: string, body: object): Promise<any> {
  const res = await fetch(`${baseUrl()}/rest/v1/${table}`, {
    method: 'POST', headers: headers(), body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`DB insert ${table}: ${await res.text()}`)
  const data = await res.json()
  return Array.isArray(data) ? data[0] : data
}

export async function dbUpdate(table: string, filter: string, body: object): Promise<void> {
  const res = await fetch(`${baseUrl()}/rest/v1/${table}?${filter}`, {
    method: 'PATCH',
    headers: { ...headers(), 'Prefer': 'return=minimal' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`DB update ${table}: ${await res.text()}`)
}
