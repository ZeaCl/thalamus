import type { ThalamusConfig, AuthorizationUrlOptions, TokenExchangeOptions, ClientCredentialsOptions, RefreshTokenOptions, TokenResponse, ThalamusError } from '../types'

export class OAuth2 {
  constructor(private config: ThalamusConfig) {}

  getAuthorizationUrl(options?: AuthorizationUrlOptions): string {
    const { scope = this.config.defaultScopes || ['openid', 'profile', 'email'], state = this.generateState(), codeChallenge, codeChallengeMethod } = options || {}

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      scope: Array.isArray(scope) ? scope.join(' ') : scope,
      state,
    })

    if (codeChallenge) {
      params.set('code_challenge', codeChallenge)
      params.set('code_challenge_method', codeChallengeMethod || 'S256')
    }

    return `${this.config.baseUrl}/oauth/authorize?${params.toString()}`
  }

  async exchangeCode(codeOrOptions: string | TokenExchangeOptions): Promise<TokenResponse> {
    const code = typeof codeOrOptions === 'string' ? codeOrOptions : codeOrOptions.code
    const codeVerifier = typeof codeOrOptions === 'string' ? undefined : codeOrOptions.codeVerifier

    const body: Record<string, any> = { grant_type: 'authorization_code', code, client_id: this.config.clientId, redirect_uri: this.config.redirectUri }
    if (this.config.clientSecret) body.client_secret = this.config.clientSecret
    if (codeVerifier) body.code_verifier = codeVerifier

    return this.requestToken(body)
  }

  async getClientCredentialsToken(options?: ClientCredentialsOptions): Promise<TokenResponse> {
    const { scope = this.config.defaultScopes || [] } = options || {}
    const body: Record<string, any> = { grant_type: 'client_credentials', client_id: this.config.clientId, client_secret: this.config.clientSecret }
    if (scope.length > 0) body.scope = Array.isArray(scope) ? scope.join(' ') : scope
    return this.requestToken(body)
  }

  async refreshToken(options: RefreshTokenOptions): Promise<TokenResponse> {
    return this.requestToken({ grant_type: 'refresh_token', refresh_token: options.refreshToken, client_id: this.config.clientId, client_secret: this.config.clientSecret })
  }

  generateState(): string {
    const array = new Uint8Array(32)
    crypto.getRandomValues(array)
    return Array.from(array, b => b.toString(16).padStart(2, '0')).join('')
  }

  private async requestToken(body: Record<string, any>): Promise<TokenResponse> {
    const res = await fetch(`${this.config.baseUrl}/oauth/token`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
    if (!res.ok) throw await this.toError(res)
    return res.json()
  }

  private async toError(res: Response): Promise<ThalamusError> {
    let data: any = {}
    try { data = await res.json() } catch {}
    const err: ThalamusError = new Error(data.error_description || data.message || `HTTP ${res.status}`) as ThalamusError
    err.statusCode = res.status; err.error = data.error; err.error_description = data.error_description
    return err
  }
}
