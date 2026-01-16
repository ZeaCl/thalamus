/**
 * @zea/thalamus-js
 *
 * Official JavaScript/TypeScript SDK for ZEA Thalamus OAuth2 Server
 *
 * @packageDocumentation
 */

export { ThalamusClient } from './ThalamusClient'
export { OAuth2 } from './auth/OAuth2'
export { TokenManager } from './tokens/TokenManager'

export type {
  ThalamusConfig,
  TokenResponse,
  IntrospectionResponse,
  UserInfo,
  AuthorizationUrlOptions,
  TokenExchangeOptions,
  ClientCredentialsOptions,
  RefreshTokenOptions,
  ThalamusError,
} from './types'

// Default export
export { ThalamusClient as default } from './ThalamusClient'
