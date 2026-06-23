export interface ThalamusConfig {
  clientId: string
  clientSecret?: string
  redirectUri: string
  baseUrl: string
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
  sub?: string
  token_type?: string
  exp?: number
  iat?: number
  nbf?: number
  aud?: string
  iss?: string
  jti?: string
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

export interface User {
  id: string
  name: string
  email: string
  status: string
  organization_id?: string
  is_agent: boolean
  agent_config?: AgentConfig
}

export interface Organization {
  id: string
  name: string
  domains?: string[]
}

export interface Role {
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

export interface AgentConfig {
  system_prompt?: string
  skills?: string[]
  icon?: string
  model?: string
  mcp_servers?: MCPServerConfig[]
  custom_skills?: CustomSkill[]
}

export interface MCPServerConfig {
  name: string
  type: 'cli' | 'url' | 'sse'
  command?: string
  url?: string
  tools_filter?: string[]
  enabled: boolean
}

export interface CustomSkill {
  name: string
  description: string
  body: string
}
