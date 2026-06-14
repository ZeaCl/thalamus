export { A as AdminAPI, O as OAuth2, T as ThalamusClient, a as TokenManager, U as UseAdminOptions, b as UseAdminReturn, c as UseThalamusOptions, d as UseThalamusReturn, u as useAdmin, e as useThalamus } from './index-D1habPPu.js';
export { APIKeyManager, APIKeyManagerProps, LoginButton, LoginButtonProps, OrgManager, OrgManagerProps, OrgSwitcher, OrgSwitcherProps, RegisterButton, RegisterButtonProps, StatusBadge, UserCreateForm, UserCreateFormProps, UserMenu, UserMenuProps, UserTable, UserTableProps } from './components/index.js';
import React from 'react';
import { T as ThalamusConfig } from './index-CMe3IpNt.js';
export { A as AgentConfig, D as DomainRole, I as IntrospectionResponse, O as Organization, R as Role, a as ThalamusError, b as TokenResponse, U as User, c as UserInfo } from './index-CMe3IpNt.js';

interface ThalamusPanelProps {
    config: ThalamusConfig;
    onNavigate?: (view: string) => void;
}
declare function ThalamusPanel({ config, onNavigate }: ThalamusPanelProps): React.JSX.Element;

export { ThalamusConfig, ThalamusPanel, type ThalamusPanelProps };
