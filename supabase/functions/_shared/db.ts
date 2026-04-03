// Raw PostgREST helper — no @supabase/supabase-js, no session management

function getHeaders() {
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  return {
    'apikey': key,
    'Authorization': `Bearer ${key}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  }
}

function getUrl() {
  return Deno.env.get('SUPABASE_URL')!
}

export async function dbSelect(table: string, query: string): Promise<any[]> {
  const res = await fetch(`${getUrl()}/rest/v1/${table}?${query}`, { headers: getHeaders() })
  if (!res.ok) {
    const text = await res.text()
    console.error(`[DB] select ${table} ${res.status}:`, text)
    throw new Error(`DB error: ${text}`)
  }
  return res.json()
}

export async function dbInsert(table: string, body: object): Promise<any> {
  const res = await fetch(`${getUrl()}/rest/v1/${table}`, {
    method: 'POST', headers: getHeaders(), body: JSON.stringify(body),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error(`[DB] insert ${table} ${res.status}:`, text)
    throw new Error(`DB error: ${text}`)
  }
  const data = await res.json()
  return Array.isArray(data) ? data[0] : data
}

export async function dbUpdate(table: string, filter: string, body: object): Promise<void> {
  const headers = { ...getHeaders(), 'Prefer': 'return=minimal' }
  const res = await fetch(`${getUrl()}/rest/v1/${table}?${filter}`, {
    method: 'PATCH', headers, body: JSON.stringify(body),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error(`[DB] update ${table} ${res.status}:`, text)
    throw new Error(`DB error: ${text}`)
  }
}
