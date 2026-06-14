import type { ThalamusConfig, ThalamusError, AgentConfig, User, Organization, Role, DomainRole } from '../types'

export class AdminAPI {
  constructor(private config: ThalamusConfig) {}

  private getAccessToken(): string | null {
    try { const saved = localStorage.getItem('thalamus_auth'); return saved ? JSON.parse(saved).accessToken : null } catch { return null }
  }

  private async request(url: string, opts: RequestInit = {}): Promise<Response> {
    const token = this.getAccessToken()
    const res = await fetch(url, { ...opts, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...opts.headers } })
    if (!res.ok) throw await this.toError(res)
    return res
  }

  private async toError(res: Response): Promise<ThalamusError> {
    let data: any = {}
    try { data = await res.json() } catch {}
    const err: ThalamusError = new Error(data.error_description || data.error || `HTTP ${res.status}`) as ThalamusError
    err.statusCode = res.status; err.error = data.error; err.error_description = data.error_description
    return err
  }

  // ── Users ──
  async listUsers(): Promise<User[]> { const r = await this.request(`${this.config.baseUrl}/api/users`); const j = await r.json(); return j.data ?? j }
  async listAgents(): Promise<User[]> { const users = await this.listUsers(); return users.filter(u => u.is_agent) }
  async getUser(id: string): Promise<User> { const r = await this.request(`${this.config.baseUrl}/api/users/${id}`); const j = await r.json(); return j.data ?? j }
  async createUser(data: { email: string; password: string; name?: string; is_agent?: boolean; agent_config?: AgentConfig }): Promise<User> { const r = await this.request(`${this.config.baseUrl}/api/users`, { method: 'POST', body: JSON.stringify({ user: data }) }); const j = await r.json(); return j.data ?? j }
  async updateUser(id: string, data: Partial<Pick<User, 'name' | 'agent_config'>>): Promise<User> { const r = await this.request(`${this.config.baseUrl}/api/users/${id}`, { method: 'PATCH', body: JSON.stringify({ user: data }) }); const j = await r.json(); return j.data ?? j }

  // ── Organizations ──
  async listOrganizations(): Promise<Organization[]> { const r = await this.request(`${this.config.baseUrl}/api/organizations`); const j = await r.json(); return j.data ?? j }
  async getOrganization(id: string): Promise<Organization> { const r = await this.request(`${this.config.baseUrl}/api/organizations/${id}`); const j = await r.json(); return j.data ?? j }
  async addOrgMember(orgId: string, userId: string): Promise<{ message: string }> { const r = await this.request(`${this.config.baseUrl}/api/organizations/${orgId}/members`, { method: 'POST', body: JSON.stringify({ user_id: userId }) }); return r.json() }

  // ── Roles ──
  async listRoles(): Promise<Role[]> { const r = await this.request(`${this.config.baseUrl}/api/roles`); const j = await r.json(); return j.data ?? j }

  // ── Domain Roles ──
  async listDomainRoles(filters?: { user_id?: string; organization_id?: string; domain?: string }): Promise<DomainRole[]> {
    const p = new URLSearchParams(); if (filters?.user_id) p.set('user_id', filters.user_id); if (filters?.organization_id) p.set('organization_id', filters.organization_id); if (filters?.domain) p.set('domain', filters.domain)
    const qs = p.toString(); const r = await this.request(`${this.config.baseUrl}/api/domains/roles${qs ? `?${qs}` : ''}`); const j = await r.json(); return j.data ?? j
  }
  async grantDomainRole(p: { user_id: string; organization_id: string; domain: string; role: string; scopes?: string[]; entity_id?: string }): Promise<{ message: string }> { const r = await this.request(`${this.config.baseUrl}/api/domains/roles/grant`, { method: 'POST', body: JSON.stringify(p) }); return r.json() }
  async revokeDomainRole(p: { user_id: string; organization_id: string; domain: string; role: string }): Promise<{ message: string }> { const r = await this.request(`${this.config.baseUrl}/api/domains/roles/revoke`, { method: 'DELETE', body: JSON.stringify(p) }); return r.json() }
}
