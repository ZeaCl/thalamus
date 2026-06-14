import type { ThalamusConfig, IntrospectionResponse, UserInfo, ThalamusError } from '../types'

export class TokenManager {
  constructor(private config: ThalamusConfig) {}

  async introspect(token: string): Promise<IntrospectionResponse> {
    const res = await fetch(`${this.config.baseUrl}/oauth/introspect`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token }) })
    if (!res.ok) throw await this.toError(res)
    return res.json()
  }

  async getUserInfo(accessToken: string): Promise<UserInfo> {
    const res = await fetch(`${this.config.baseUrl}/oauth/userinfo`, { headers: { Authorization: `Bearer ${accessToken}` } })
    if (!res.ok) throw await this.toError(res)
    return res.json()
  }

  async validate(token: string): Promise<boolean> {
    try { return (await this.introspect(token)).active === true } catch { return false }
  }

  private async toError(res: Response): Promise<ThalamusError> {
    let data: any = {}
    try { data = await res.json() } catch {}
    const err: ThalamusError = new Error(data.error_description || data.message || `HTTP ${res.status}`) as ThalamusError
    err.statusCode = res.status; err.error = data.error; err.error_description = data.error_description
    return err
  }
}
