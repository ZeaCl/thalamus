import { T as ThalamusConfig, d as AuthorizationUrlOptions, e as TokenExchangeOptions, b as TokenResponse, C as ClientCredentialsOptions, f as RefreshTokenOptions, I as IntrospectionResponse, c as UserInfo, U as User, A as AgentConfig, O as Organization, R as Role, D as DomainRole } from './index-CMe3IpNt.mjs';

declare class OAuth2 {
    private config;
    constructor(config: ThalamusConfig);
    getAuthorizationUrl(options?: AuthorizationUrlOptions): string;
    exchangeCode(codeOrOptions: string | TokenExchangeOptions): Promise<TokenResponse>;
    getClientCredentialsToken(options?: ClientCredentialsOptions): Promise<TokenResponse>;
    refreshToken(options: RefreshTokenOptions): Promise<TokenResponse>;
    generateState(): string;
    private requestToken;
    private toError;
}

declare class TokenManager {
    private config;
    constructor(config: ThalamusConfig);
    introspect(token: string): Promise<IntrospectionResponse>;
    getUserInfo(accessToken: string): Promise<UserInfo>;
    validate(token: string): Promise<boolean>;
    private toError;
}

declare class AdminAPI {
    private config;
    constructor(config: ThalamusConfig);
    private getAccessToken;
    private request;
    private toError;
    listUsers(): Promise<User[]>;
    listAgents(): Promise<User[]>;
    getUser(id: string): Promise<User>;
    createUser(data: {
        email: string;
        password: string;
        name?: string;
        is_agent?: boolean;
        agent_config?: AgentConfig;
    }): Promise<User>;
    updateUser(id: string, data: Partial<Pick<User, 'name' | 'agent_config'>>): Promise<User>;
    listOrganizations(): Promise<Organization[]>;
    getOrganization(id: string): Promise<Organization>;
    addOrgMember(orgId: string, userId: string): Promise<{
        message: string;
    }>;
    listRoles(): Promise<Role[]>;
    listDomainRoles(filters?: {
        user_id?: string;
        organization_id?: string;
        domain?: string;
    }): Promise<DomainRole[]>;
    grantDomainRole(p: {
        user_id: string;
        organization_id: string;
        domain: string;
        role: string;
        scopes?: string[];
        entity_id?: string;
    }): Promise<{
        message: string;
    }>;
    revokeDomainRole(p: {
        user_id: string;
        organization_id: string;
        domain: string;
        role: string;
    }): Promise<{
        message: string;
    }>;
}

declare class ThalamusClient {
    readonly auth: OAuth2;
    readonly tokens: TokenManager;
    readonly admin: AdminAPI;
    private readonly config;
    constructor(config: ThalamusConfig);
    getConfig(): Readonly<ThalamusConfig>;
}

interface UseThalamusOptions extends ThalamusConfig {
    /** Storage key for persisting auth (default: 'thalamus_auth') */
    storageKey?: string;
}
interface UseThalamusReturn {
    /** Start OAuth2 PKCE login flow (redirects browser) */
    login: (options?: {
        scope?: string[];
    }) => Promise<void>;
    /** Clear stored token and reset state */
    logout: () => void;
    /** Raw access token */
    token: string | null;
    /** Decoded user info */
    user: UserInfo | null;
    /** Whether authenticated */
    isAuthenticated: boolean;
    /** Whether loading auth state */
    isLoading: boolean;
    /** Refresh the access token */
    refreshToken: () => Promise<void>;
    /** ThalamusClient instance for direct API calls */
    client: ThalamusClient;
    /** Error message if any */
    error: string | null;
}
declare function useThalamus(options: UseThalamusOptions): UseThalamusReturn;

interface UseAdminOptions {
    baseUrl: string;
    /** If true, auto-fetches on mount */
    autoFetch?: boolean;
}
interface UseAdminReturn {
    users: User[];
    agents: User[];
    organizations: Organization[];
    roles: Role[];
    loading: boolean;
    error: string | null;
    refresh: () => Promise<void>;
    createUser: (data: {
        email: string;
        password: string;
        name?: string;
        is_agent?: boolean;
    }) => Promise<User | null>;
    listDomainRoles: (filters?: {
        user_id?: string;
        organization_id?: string;
        domain?: string;
    }) => Promise<DomainRole[]>;
}
declare function useAdmin(options: UseAdminOptions): UseAdminReturn;

export { AdminAPI as A, OAuth2 as O, ThalamusClient as T, type UseAdminOptions as U, TokenManager as a, type UseAdminReturn as b, type UseThalamusOptions as c, type UseThalamusReturn as d, useThalamus as e, useAdmin as u };
