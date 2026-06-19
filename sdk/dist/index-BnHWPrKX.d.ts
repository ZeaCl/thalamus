interface ThalamusConfig {
    clientId: string;
    clientSecret?: string;
    redirectUri: string;
    baseUrl: string;
    defaultScopes?: string[];
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

export type { DomainRole as D, Organization as O, Role as R, ThalamusConfig as T, UserInfo as U, User as a };
