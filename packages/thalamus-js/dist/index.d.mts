/**
 * ZEA Thalamus SDK Types
 *
 * TypeScript type definitions for the Thalamus OAuth2 SDK
 */
interface ThalamusConfig {
    /** OAuth2 Client ID */
    clientId: string;
    /** OAuth2 Client Secret (for confidential clients) */
    clientSecret?: string;
    /** Redirect URI for authorization callback */
    redirectUri: string;
    /** Thalamus base URL (e.g., https://auth.example.com) */
    baseUrl: string;
    /** Default scopes to request */
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
    tenant_id?: string;
    token_type?: string;
    exp?: number;
    iat?: number;
    sub?: string;
    agent_type?: 'autonomous' | 'supervised' | 'ephemeral';
    delegated_by?: string;
    delegation_chain?: string[];
    delegation_depth?: number;
    task_id?: string;
    max_operations?: number;
    operations_remaining?: number;
    expires_on_completion?: boolean;
    intent_description?: string;
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

/**
 * OAuth2 Authentication Module
 *
 * Handles OAuth2 authorization code flow, client credentials, and token refresh
 */

declare class OAuth2 {
    private config;
    constructor(config: ThalamusConfig);
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
    getAuthorizationUrl(options?: AuthorizationUrlOptions): string;
    /**
     * Exchange authorization code for access token
     *
     * @example
     * ```ts
     * const tokens = await thalamus.auth.exchangeCode('authorization_code_here')
     * console.log(tokens.access_token)
     * ```
     */
    exchangeCode(codeOrOptions: string | TokenExchangeOptions): Promise<TokenResponse>;
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
    getClientCredentialsToken(options?: ClientCredentialsOptions): Promise<TokenResponse>;
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
    refreshToken(options: RefreshTokenOptions): Promise<TokenResponse>;
    /**
     * Revoke a token (access or refresh token)
     *
     * @example
     * ```ts
     * await thalamus.auth.revokeToken('at_...')
     * ```
     */
    revokeToken(token: string, tokenTypeHint?: 'access_token' | 'refresh_token'): Promise<void>;
    /**
     * Generate random state for CSRF protection
     */
    private generateState;
    /**
     * Make token request to /oauth/token
     */
    private requestToken;
    /**
     * Handle API errors
     */
    private handleError;
}

/**
 * Token Management Module
 *
 * Handles token introspection and validation
 */

declare class TokenManager {
    private config;
    constructor(config: ThalamusConfig);
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
    introspect(token: string): Promise<IntrospectionResponse>;
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
    getUserInfo(accessToken: string): Promise<UserInfo>;
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
    validate(token: string): Promise<boolean>;
    /**
     * Handle API errors
     */
    private handleError;
}

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

declare class ThalamusClient {
    /** OAuth2 authentication methods */
    readonly auth: OAuth2;
    /** Token management and introspection */
    readonly tokens: TokenManager;
    private readonly config;
    /**
     * Create a new Thalamus client
     *
     * @param config - Client configuration
     */
    constructor(config: ThalamusConfig);
    /**
     * Get the current configuration
     */
    getConfig(): Readonly<ThalamusConfig>;
}

export { type AuthorizationUrlOptions, type ClientCredentialsOptions, type IntrospectionResponse, OAuth2, type RefreshTokenOptions, ThalamusClient, type ThalamusConfig, type ThalamusError, type TokenExchangeOptions, TokenManager, type TokenResponse, type UserInfo, ThalamusClient as default };
