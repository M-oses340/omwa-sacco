// Raw PostgREST helper — no Supabase JS client, no session management

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

// deno-lint-ignore no-explicit-any
export async function dbSelect(table: string, query: string): Promise<any[]> {
  const res = await fetch(`${getUrl()}/rest/v1/${table}?${query}`, { headers: getHeaders() })
  if (!res.ok) {
    const body = await res.text()
    throw new Error(`DB ${table}: ${body}`)
  }
  return res.json()
}

// deno-lint-ignore no-explicit-any
export async function dbInsert(table: string, body: object): Promise<any> {
  const res = await fetch(`${getUrl()}/rest/v1/${table}`, {
    method: 'POST', headers: getHeaders(), body: JSON.stringify(body),
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(`DB insert ${table}: ${err}`)
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
    const err = await res.text()
    throw new Error(`DB update ${table}: ${err}`)
  }
}
