'use client'

import { useState, useEffect, useRef } from 'react'
import { ThalamusClient } from '../client/ThalamusClient'
import type { User, Organization, Role, DomainRole, ThalamusConfig } from '../types'

export interface UseAdminOptions {
  baseUrl: string
  /** If true, auto-fetches on mount */
  autoFetch?: boolean
}

export interface UseAdminReturn {
  users: User[]
  agents: User[]
  organizations: Organization[]
  roles: Role[]
  loading: boolean
  error: string | null
  refresh: () => Promise<void>
  createUser: (data: { email: string; password: string; name?: string; is_agent?: boolean }) => Promise<User | null>
  listDomainRoles: (filters?: { user_id?: string; organization_id?: string; domain?: string }) => Promise<DomainRole[]>
}

export function useAdmin(options: UseAdminOptions): UseAdminReturn {
  const { baseUrl } = options
  const clientRef = useRef(new ThalamusClient({ clientId: 'admin', redirectUri: typeof window !== 'undefined' ? window.location.origin : 'http://localhost', baseUrl }))
  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refresh = async () => {
    setLoading(true); setError(null)
    try {
      const u = await clientRef.current.admin.listUsers()
      setUsers(u)
    } catch (e: any) { setError(e.message) }
    setLoading(false)
  }

  useEffect(() => { if (options.autoFetch !== false) refresh() }, [baseUrl])

  const agents = users.filter(u => u.is_agent)
  const organizations: Organization[] = []
  const roles: Role[] = []

  const createUser = async (data: { email: string; password: string; name?: string; is_agent?: boolean }) => {
    try { const u = await clientRef.current.admin.createUser(data); setUsers(prev => [...prev, u]); return u } catch (e: any) { setError(e.message); return null }
  }

  const listDomainRoles = async (filters?: { user_id?: string; organization_id?: string; domain?: string }) => {
    return clientRef.current.admin.listDomainRoles(filters)
  }

  return { users, agents, organizations, roles, loading, error, refresh, createUser, listDomainRoles }
}
