import { OAuth2 } from './OAuth2'
import { TokenManager } from './TokenManager'
import { AdminAPI } from './AdminAPI'
import type { ThalamusConfig } from '../types'

export class ThalamusClient {
  readonly auth: OAuth2
  readonly tokens: TokenManager
  readonly admin: AdminAPI
  private readonly config: ThalamusConfig

  constructor(config: ThalamusConfig) {
    if (!config.clientId) throw new Error('clientId is required')
    if (!config.redirectUri) throw new Error('redirectUri is required')
    if (!config.baseUrl) throw new Error('baseUrl is required')
    config.baseUrl = config.baseUrl.replace(/\/$/, '')
    this.config = config
    this.auth = new OAuth2(config)
    this.tokens = new TokenManager(config)
    this.admin = new AdminAPI(config)
  }

  getConfig(): Readonly<ThalamusConfig> { return Object.freeze({ ...this.config }) }
}
