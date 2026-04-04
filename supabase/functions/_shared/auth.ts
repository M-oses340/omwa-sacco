import { createRemoteJWKSet, jwtVerify } from 'https://esm.sh/jose@5'

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

export async function getAuthUserId(req: Request, bodyJwt?: string): Promise<string | null> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const JWKS = createRemoteJWKSet(
    new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`)
  )

  // Try Authorization header first, fall back to body.jwt
  let token: string | null = null
  const authHeader = req.headers.get('Authorization')
  if (authHeader?.startsWith('Bearer ')) {
    const t = authHeader.slice(7)
    // Skip anon key (HS256) — only accept user JWTs (ES256)
    if (!t.startsWith('eyJhbGciOiJIUzI1NiJ')) {
      token = t
    }
  }
  if (!token && bodyJwt) token = bodyJwt

  if (!token) return null

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `${supabaseUrl}/auth/v1`,
      audience: 'authenticated',
    })
    return (payload.sub as string) ?? null
  } catch (e) {
    console.error('[AUTH] JWT verify failed:', (e as Error).message)
    return null
  }
}
