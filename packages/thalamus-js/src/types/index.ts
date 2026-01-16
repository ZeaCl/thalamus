/**
 * ZEA Thalamus SDK Types
 *
 * TypeScript type definitions for the Thalamus OAuth2 SDK
 */

export interface ThalamusConfig {
  /** OAuth2 Client ID */
  clientId: string
  /** OAuth2 Client Secret (for confidential clients) */
  clientSecret?: string
  /** Redirect URI for authorization callback */
  redirectUri: string
  /** Thalamus base URL (e.g., https://auth.example.com) */
  baseUrl: string
  /** Default scopes to request */
  defaultScopes?: string[]
}

export interface TokenResponse {
  access_token: string
  token_type: 'Bearer'
  expires_in: number
  refresh_token?: string
  scope?: string
}

export interface IntrospectionResponse {
  active: boolean
  scope?: string
  client_id?: string
  user_id?: string
  username?: string
  email?: string
  organization_id?: string
  tenant_id?: string
  token_type?: string
  exp?: number
  iat?: number
  sub?: string
  // Agent-specific fields
  agent_type?: 'autonomous' | 'supervised' | 'ephemeral'
  delegated_by?: string
  delegation_chain?: string[]
  delegation_depth?: number
  task_id?: string
  max_operations?: number
  operations_remaining?: number
  expires_on_completion?: boolean
  intent_description?: string
}

export interface UserInfo {
  sub: string
  email?: string
  email_verified?: boolean
  name?: string
  given_name?: string
  family_name?: string
  picture?: string
  organization_id?: string
}

export interface AuthorizationUrlOptions {
  scope?: string[]
  state?: string
  responseType?: 'code'
  codeChallenge?: string
  codeChallengeMethod?: 'S256'
}

export interface TokenExchangeOptions {
  code: string
  codeVerifier?: string
}

export interface ClientCredentialsOptions {
  scope?: string[]
}

export interface RefreshTokenOptions {
  refreshToken: string
}

export interface ThalamusError extends Error {
  statusCode?: number
  error?: string
  error_description?: string
}
