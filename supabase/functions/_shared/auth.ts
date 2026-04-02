// Shared JWT decode utility — works with ES256 tokens from Supabase Auth
// Does NOT call supabase.auth.getUser() — avoids "Session expired" bug in CLI 2.84.x

export function jwtUserId(authHeader: string | null): string | null {
  try {
    if (!authHeader?.startsWith('Bearer ')) return null
    const parts = authHeader.split('.')
    if (parts.length !== 3) return null
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const pad = b64.length % 4 === 0 ? '' : '='.repeat(4 - b64.length % 4)
    const decoded = new TextDecoder().decode(
      Uint8Array.from(atob(b64 + pad), (c) => c.charCodeAt(0))
    )
    const data = JSON.parse(decoded)
    if (data.role !== 'authenticated') return null
    if (data.exp && data.exp < Math.floor(Date.now() / 1000)) return null
    return data.sub as string ?? null
  } catch {
    return null
  }
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
