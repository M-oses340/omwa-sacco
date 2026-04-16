'use client'
import { useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true); setError('')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) setError(error.message)
    setLoading(false)
  }

  return (
    <div className="flex items-center justify-center h-screen bg-gray-50 dark:bg-gray-950">
      <div className="bg-white dark:bg-gray-900 rounded-2xl shadow p-8 w-full max-w-sm border border-gray-100 dark:border-gray-800">
        <h1 className="text-2xl font-bold text-green-700 dark:text-green-400 mb-1">Omwa Sacco</h1>
        <p className="text-gray-500 dark:text-gray-400 text-sm mb-6">Admin Dashboard</p>
        <form onSubmit={handleLogin} className="flex flex-col gap-4">
          <input
            type="email" required placeholder="Email"
            value={email} onChange={e => setEmail(e.target.value)}
            className="border dark:border-gray-700 rounded-lg px-4 py-2 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500"
          />
          <input
            type="password" required placeholder="Password"
            value={password} onChange={e => setPassword(e.target.value)}
            className="border dark:border-gray-700 rounded-lg px-4 py-2 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500"
          />
          {error && <p className="text-red-500 text-xs">{error}</p>}
          <button disabled={loading}
            className="bg-green-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-green-700 disabled:opacity-50">
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  )
}
