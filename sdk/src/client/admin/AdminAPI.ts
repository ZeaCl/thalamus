/**
 * Admin API Module
 *
 * User, organization, role, and domain management endpoints.
 * Requires JWT Bearer token authentication.
 */

import type { ThalamusConfig, ThalamusError, AgentConfig, MCPServerConfig } from '../types'

// ── Types ────────────────────────────────────────────────────────────────────

export interface User {
  id: string
  name: string
  email: string
  status: string
  organization_id?: string
  is_agent: boolean
  agent_config?: AgentConfig
}

export interface AdminOrganization {
  id: string
  name: string
  domains?: string[]
}

export interface AdminRole {
  id: string
  organization_id: string
  name: string
  description?: string
  scopes: string[]
}

export interface DomainRole {
  id: string
  user_id: string
  organization_id: string
  domain: string
  role: string
  scopes: string[]
}

export interface EffectiveScopes {
  user_id: string
  scopes: string[]
}

// ── AdminAPI ─────────────────────────────────────────────────────────────────

export class AdminAPI {
  constructor(private config: ThalamusConfig) {}

  private get baseUrl(): string {
    return this.config.baseUrl
  }

  // ── Users ────────────────────────────────────────────────────────────────

  /** List all users */
  async listUsers(): Promise<User[]> {
    const res = await this.request(`${this.baseUrl}/api/users`)
    const json: any = await res.json()
    return json.data ?? json
  }

  /** List all agents (users with is_agent === true) */
  async listAgents(): Promise<User[]> {
    const users = await this.listUsers()
    return users.filter((u) => u.is_agent === true)
  }

  /** Get a single user */
  async getUser(id: string): Promise<User> {
    const res = await this.request(`${this.baseUrl}/api/users/${id}`)
    const json: any = await res.json()
    return json.data ?? json
  }

  /** Add a member to an organization */
  async addOrgMember(orgId: string, userId: string): Promise<{ message: string }> {
    const res = await this.request(`${this.baseUrl}/api/organizations/${orgId}/members`, {
      method: 'POST',
      body: JSON.stringify({ user_id: userId }),
    })
    return res.json() as Promise<{ message: string }>
  }

  /** Update a user (only name and agent_config are writable) */
  async updateUser(id: string, data: Partial<Pick<User, 'name' | 'agent_config'>>): Promise<User> {
    const res = await this.request(`${this.baseUrl}/api/users/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ user: data }),
    })
    const json: any = await res.json()
    return json.data ?? json
  }

  /** Create a user */
  async createUser(data: {
    email: string
    password: string
    name?: string
    is_agent?: boolean
    agent_config?: AgentConfig
  }): Promise<User> {
    const res = await this.request(`${this.baseUrl}/api/users`, {
      method: 'POST',
      body: JSON.stringify({ user: data }),
    })
    const json: any = await res.json()
    return json.data ?? json
  }

  // ── Organizations ─────────────────────────────────────────────────────────

  /** Get an organization */
  async getOrganization(id: string): Promise<AdminOrganization> {
    const res = await this.request(`${this.baseUrl}/api/organizations/${id}`)
    const json: any = await res.json()
    return json.data ?? json
  }

  /** List all organizations */
  async listOrganizations(): Promise<AdminOrganization[]> {
    const res = await this.request(`${this.baseUrl}/api/organizations`)
    const json: any = await res.json()
    return json.data ?? json
  }

  // ── Domain Roles ──────────────────────────────────────────────────────────

  /** List domain roles (optionally filtered) */
  async listDomainRoles(filters?: {
    user_id?: string
    organization_id?: string
    domain?: string
  }): Promise<DomainRole[]> {
    const params = new URLSearchParams()
    if (filters?.user_id) params.set('user_id', filters.user_id)
    if (filters?.organization_id) params.set('organization_id', filters.organization_id)
    if (filters?.domain) params.set('domain', filters.domain)

    const qs = params.toString()
    const url = `${this.baseUrl}/api/domains/roles${qs ? `?${qs}` : ''}`
    const res = await this.request(url)
    const json: any = await res.json()
    return json.data ?? json
  }

  /** Grant a domain role to a user */
  async grantDomainRole(params: {
    user_id: string
    organization_id: string
    domain: string
    role: string
    scopes?: string[]
    entity_id?: string
  }): Promise<{ message: string }> {
    const res = await this.request(`${this.baseUrl}/api/domains/roles/grant`, {
      method: 'POST',
      body: JSON.stringify(params),
    })
    return res.json() as Promise<{ message: string }>
  }

  /** Revoke a domain role from a user */
  async revokeDomainRole(params: {
    user_id: string
    organization_id: string
    domain: string
    role: string
  }): Promise<{ message: string }> {
    const res = await this.request(`${this.baseUrl}/api/domains/roles/revoke`, {
      method: 'DELETE',
      body: JSON.stringify(params),
    })
    return res.json() as Promise<{ message: string }>
  }

  // ── Roles (RBAC) ──────────────────────────────────────────────────────────

  /** List all roles */
  async listRoles(): Promise<AdminRole[]> {
    const res = await this.request(`${this.baseUrl}/api/roles`)
    const json: any = await res.json()
    return json.data ?? json
  }

  /** Create a role */
  async createRole(params: {
    organization_id: string
    name: string
    description?: string
    scopes: string[]
  }): Promise<AdminRole> {
    const res = await this.request(`${this.baseUrl}/api/roles`, {
      method: 'POST',
      body: JSON.stringify(params),
    })
    const json: any = await res.json()
    return json.data ?? json
  }

  /** Delete a role */
  async deleteRole(id: string): Promise<void> {
    await this.request(`${this.baseUrl}/api/roles/${id}`, { method: 'DELETE' })
  }

  // ── User Roles ────────────────────────────────────────────────────────────

  /** Get user's effective scopes */
  async getEffectiveScopes(userId: string): Promise<EffectiveScopes> {
    const res = await this.request(`${this.baseUrl}/api/users/${userId}/effective-scopes`)
    const json: any = await res.json()
    return json.data ?? json
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  private getAccessToken(): string | null {
    if (typeof globalThis !== 'undefined' && 'localStorage' in globalThis) {
      const storageKey = (this.config as any).storageKey || 'thalamus_auth'
      const saved = (globalThis as any).localStorage.getItem(storageKey)
      if (saved) {
        try {
          return JSON.parse(saved).accessToken
        } catch {
          return null
        }
      }
    }
    return null
  }

  private async request(url: string, options: RequestInit = {}): Promise<Response> {
    const token = this.getAccessToken()

    const res = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...options.headers,
      },
    })

    if (!res.ok) {
      if (res.status === 401 && typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('thalamus:unauthorized'))
        if (window.parent && window.parent !== window) {
          window.parent.postMessage({ type: 'thalamus:unauthorized' }, '*')
        }
      }
      throw await this.toError(res)
    }

    return res
  }

  private async toError(response: Response): Promise<ThalamusError> {
    let body: any = {}
    try {
      body = await response.json()
    } catch {
      // ignore
    }

    const error: ThalamusError = new Error(
      body.error_description || body.error || `HTTP ${response.status}`
    ) as ThalamusError
    error.statusCode = response.status
    error.error = body.error
    error.error_description = body.error_description

    return error
  }
}
