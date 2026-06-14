interface ThalamusConfig {
    clientId: string;
    clientSecret?: string;
    redirectUri: string;
    baseUrl: string;
    defaultScopes?: string[];
}
interface TokenResponse {
    access_token: string;
    token_type: 'Bearer';
    expires_in: number;
    refresh_token?: string;
    scope?: string;
}
interface IntrospectionResponse {
    active: boolean;
    scope?: string;
    client_id?: string;
    user_id?: string;
    username?: string;
    email?: string;
    organization_id?: string;
    sub?: string;
}
interface UserInfo {
    sub: string;
    email?: string;
    email_verified?: boolean;
    name?: string;
    given_name?: string;
    family_name?: string;
    picture?: string;
    organization_id?: string;
}
interface AuthorizationUrlOptions {
    scope?: string[];
    state?: string;
    responseType?: 'code';
    codeChallenge?: string;
    codeChallengeMethod?: 'S256';
}
interface TokenExchangeOptions {
    code: string;
    codeVerifier?: string;
}
interface ClientCredentialsOptions {
    scope?: string[];
}
interface RefreshTokenOptions {
    refreshToken: string;
}
interface ThalamusError extends Error {
    statusCode?: number;
    error?: string;
    error_description?: string;
}
interface User {
    id: string;
    name: string;
    email: string;
    status: string;
    organization_id?: string;
    is_agent: boolean;
    agent_config?: AgentConfig;
}
interface Organization {
    id: string;
    name: string;
    domains?: string[];
}
interface Role {
    id: string;
    organization_id: string;
    name: string;
    description?: string;
    scopes: string[];
}
interface DomainRole {
    id: string;
    user_id: string;
    organization_id: string;
    domain: string;
    role: string;
    scopes: string[];
}
interface AgentConfig {
    system_prompt?: string;
    skills?: string[];
    icon?: string;
    model?: string;
    mcp_servers?: MCPServerConfig[];
    custom_skills?: CustomSkill[];
}
interface MCPServerConfig {
    name: string;
    type: 'cli' | 'url' | 'sse';
    command?: string;
    url?: string;
    tools_filter?: string[];
    enabled: boolean;
}
interface CustomSkill {
    name: string;
    description: string;
    body: string;
}

export type { AgentConfig as A, ClientCredentialsOptions as C, DomainRole as D, IntrospectionResponse as I, Organization as O, Role as R, ThalamusConfig as T, User as U, ThalamusError as a, TokenResponse as b, UserInfo as c, AuthorizationUrlOptions as d, TokenExchangeOptions as e, RefreshTokenOptions as f };
