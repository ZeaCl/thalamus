/**
 * Token Management Module
 *
 * Handles token introspection and validation
 */

import type {
  ThalamusConfig,
  IntrospectionResponse,
  UserInfo,
  ThalamusError,
} from '../types'

export class TokenManager {
  constructor(private config: ThalamusConfig) {}

  /**
   * Introspect a token to check if it's valid and get metadata
   *
   * @example
   * ```ts
   * const tokenInfo = await thalamus.tokens.introspect('at_...')
   * if (tokenInfo.active) {
   *   console.log(tokenInfo.user_id)
   *   console.log(tokenInfo.scope)
   * }
   * ```
   */
  async introspect(token: string): Promise<IntrospectionResponse> {
    const response = await fetch(`${this.config.baseUrl}/oauth/introspect`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ token }),
    })

    if (!response.ok) {
      throw await this.handleError(response)
    }

    return response.json() as Promise<IntrospectionResponse>
  }

  /**
   * Get user information from OpenID Connect userinfo endpoint
   *
   * @example
   * ```ts
   * const user = await thalamus.tokens.getUserInfo('at_...')
   * console.log(user.email)
   * console.log(user.name)
   * ```
   */
  async getUserInfo(accessToken: string): Promise<UserInfo> {
    const response = await fetch(`${this.config.baseUrl}/oauth/userinfo`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    })

    if (!response.ok) {
      throw await this.handleError(response)
    }

    return response.json() as Promise<UserInfo>
  }

  /**
   * Validate token and return true if active, false otherwise
   *
   * @example
   * ```ts
   * const isValid = await thalamus.tokens.validate('at_...')
   * if (isValid) {
   *   // Token is valid
   * }
   * ```
   */
  async validate(token: string): Promise<boolean> {
    try {
      const result = await this.introspect(token)
      return result.active === true
    } catch {
      return false
    }
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
