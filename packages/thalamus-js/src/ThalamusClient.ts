/**
 * ZEA Thalamus OAuth2 Client
 *
 * Official JavaScript/TypeScript SDK for Thalamus OAuth2 Server
 *
 * @example
 * ```ts
 * import ThalamusClient from '@zea/thalamus-js'
 *
 * const thalamus = new ThalamusClient({
 *   clientId: process.env.THALAMUS_CLIENT_ID,
 *   clientSecret: process.env.THALAMUS_CLIENT_SECRET,
 *   redirectUri: 'https://yourapp.com/auth/callback',
 *   baseUrl: 'https://auth.example.com'
 * })
 *
 * // Get authorization URL
 * const authUrl = thalamus.auth.getAuthorizationUrl()
 *
 * // Exchange code for tokens
 * const tokens = await thalamus.auth.exchangeCode(code)
 *
 * // Introspect token
 * const tokenInfo = await thalamus.tokens.introspect(accessToken)
 * ```
 */

import { OAuth2 } from './auth/OAuth2'
import { TokenManager } from './tokens/TokenManager'
import type { ThalamusConfig } from './types'

export class ThalamusClient {
  /** OAuth2 authentication methods */
  public readonly auth: OAuth2

  /** Token management and introspection */
  public readonly tokens: TokenManager

  private readonly config: ThalamusConfig

  /**
   * Create a new Thalamus client
   *
   * @param config - Client configuration
   */
  constructor(config: ThalamusConfig) {
    // Validate required config
    if (!config.clientId) {
      throw new Error('clientId is required')
    }
    if (!config.redirectUri) {
      throw new Error('redirectUri is required')
    }
    if (!config.baseUrl) {
      throw new Error('baseUrl is required')
    }

    // Remove trailing slash from baseUrl
    config.baseUrl = config.baseUrl.replace(/\/$/, '')

    this.config = config
    this.auth = new OAuth2(config)
    this.tokens = new TokenManager(config)
  }

  /**
   * Get the current configuration
   */
  getConfig(): Readonly<ThalamusConfig> {
    return Object.freeze({ ...this.config })
  }
}

export default ThalamusClient
