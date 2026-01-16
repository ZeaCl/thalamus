/**
 * OAuth2 Authentication Module
 *
 * Handles OAuth2 authorization code flow, client credentials, and token refresh
 */

import type {
  ThalamusConfig,
  TokenResponse,
  AuthorizationUrlOptions,
  TokenExchangeOptions,
  ClientCredentialsOptions,
  RefreshTokenOptions,
  ThalamusError,
} from '../types'

export class OAuth2 {
  constructor(private config: ThalamusConfig) {}

  /**
   * Generate OAuth2 authorization URL for user login
   *
   * @example
   * ```ts
   * const authUrl = thalamus.auth.getAuthorizationUrl({
   *   scope: ['openid', 'profile', 'email'],
   *   state: 'random-state-string'
   * })
   * // Redirect user to authUrl
   * ```
   */
  getAuthorizationUrl(options?: AuthorizationUrlOptions): string {
    const {
      scope = this.config.defaultScopes || ['openid', 'profile', 'email'],
      state = this.generateState(),
      responseType = 'code',
    } = options || {}

    const params = new URLSearchParams({
      response_type: responseType,
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      scope: Array.isArray(scope) ? scope.join(' ') : scope,
      state,
    })

    return `${this.config.baseUrl}/oauth/authorize?${params.toString()}`
  }

  /**
   * Exchange authorization code for access token
   *
   * @example
   * ```ts
   * const tokens = await thalamus.auth.exchangeCode('authorization_code_here')
   * console.log(tokens.access_token)
   * ```
   */
  async exchangeCode(
    codeOrOptions: string | TokenExchangeOptions
  ): Promise<TokenResponse> {
    const code = typeof codeOrOptions === 'string' ? codeOrOptions : codeOrOptions.code

    const body = {
      grant_type: 'authorization_code',
      code,
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      redirect_uri: this.config.redirectUri,
    }

    return this.requestToken(body)
  }

  /**
   * Get access token using client credentials (M2M)
   *
   * @example
   * ```ts
   * const tokens = await thalamus.auth.getClientCredentialsToken({
   *   scope: ['api:read', 'api:write']
   * })
   * ```
   */
  async getClientCredentialsToken(
    options?: ClientCredentialsOptions
  ): Promise<TokenResponse> {
    const { scope = this.config.defaultScopes || [] } = options || {}

    const body: Record<string, any> = {
      grant_type: 'client_credentials',
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
    }

    if (scope.length > 0) {
      body.scope = Array.isArray(scope) ? scope.join(' ') : scope
    }

    return this.requestToken(body)
  }

  /**
   * Refresh access token using refresh token
   *
   * @example
   * ```ts
   * const newTokens = await thalamus.auth.refreshToken({
   *   refreshToken: 'rt_...'
   * })
   * ```
   */
  async refreshToken(options: RefreshTokenOptions): Promise<TokenResponse> {
    const body = {
      grant_type: 'refresh_token',
      refresh_token: options.refreshToken,
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
    }

    return this.requestToken(body)
  }

  /**
   * Revoke a token (access or refresh token)
   *
   * @example
   * ```ts
   * await thalamus.auth.revokeToken('at_...')
   * ```
   */
  async revokeToken(token: string, tokenTypeHint?: 'access_token' | 'refresh_token'): Promise<void> {
    const body: Record<string, string> = {
      token,
    }

    if (tokenTypeHint) {
      body.token_type_hint = tokenTypeHint
    }

    const response = await fetch(`${this.config.baseUrl}/oauth/revoke`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })

    if (!response.ok) {
      throw await this.handleError(response)
    }
  }

  /**
   * Generate random state for CSRF protection
   */
  private generateState(): string {
    const array = new Uint8Array(32)
    if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
      crypto.getRandomValues(array)
    } else {
      // Fallback for Node.js
      const cryptoModule = require('crypto')
      cryptoModule.randomFillSync(array)
    }
    return Array.from(array, (byte) => byte.toString(16).padStart(2, '0')).join('')
  }

  /**
   * Make token request to /oauth/token
   */
  private async requestToken(body: Record<string, any>): Promise<TokenResponse> {
    const response = await fetch(`${this.config.baseUrl}/oauth/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })

    if (!response.ok) {
      throw await this.handleError(response)
    }

    return response.json() as Promise<TokenResponse>
  }

  /**
   * Handle API errors
   */
  private async handleError(response: Response): Promise<ThalamusError> {
    let errorData: any = {}
    try {
      errorData = await response.json()
    } catch {
      // Ignore JSON parse errors
    }

    const error: ThalamusError = new Error(
      errorData.error_description || errorData.message || `HTTP ${response.status}`
    )
    error.statusCode = response.status
    error.error = errorData.error
    error.error_description = errorData.error_description

    return error
  }
}
