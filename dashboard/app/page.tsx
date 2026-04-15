'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import Login from '@/components/Login'
import Sidebar from '@/components/Sidebar'
import Overview from '@/components/Overview'
import Members from '@/components/Members'
import Loans from '@/components/Loans'
import Reports from '@/components/Reports'
import Transactions from '@/components/Transactions'
import type { Session } from '@supabase/supabase-js'

const ADMIN_ROLES = ['admin', 'treasurer', 'chairman', 'secretary']

export default function Home() {
  const [session, setSession] = useState<Session | null>(null)
  const [member, setMember] = useState<any>(null)
  const [page, setPage] = useState('overview')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      if (session) loadMember(session.user.id)
      else setLoading(false)
    })
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_e, session) => {
      setSession(session)
      if (session) loadMember(session.user.id)
      else { setMember(null); setLoading(false) }
    })
    return () => subscription.unsubscribe()
  }, [])

  async function loadMember(userId: string) {
    const { data } = await supabase.from('members').select('id, full_name, role, status').eq('user_id', userId).single()
    setMember(data)
    setLoading(false)
  }

  if (loading) return <div className="flex items-center justify-center h-screen text-gray-500">Loading...</div>
  if (!session) return <Login />
  if (!member || !ADMIN_ROLES.includes(member.role)) {
    return (
      <div className="flex items-center justify-center h-screen flex-col gap-4">
        <p className="text-red-600 font-medium">Access denied. Admin roles only.</p>
        <button onClick={() => supabase.auth.signOut()} className="text-sm text-gray-500 underline">Sign out</button>
      </div>
    )
  }

  const pages: Record<string, React.ReactNode> = {
    overview: <Overview />,
    members: <Members />,
    loans: <Loans />,
    transactions: <Transactions />,
    reports: <Reports />,
  }

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar page={page} setPage={setPage} member={member} />
      <main className="flex-1 overflow-y-auto p-6">{pages[page]}</main>
    </div>
  )
}
