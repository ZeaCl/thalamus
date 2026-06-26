export { A as AdminAPI, a as AgentConfig, D as DomainRole, I as IntrospectionResponse, O as OAuth2, b as Organization, c as Role, T as ThalamusClient, d as ThalamusConfig, e as ThalamusError, f as TokenManager, g as TokenResponse, U as UseAdminOptions, h as UseAdminReturn, i as UseThalamusOptions, j as UseThalamusReturn, k as User, l as UserInfo, u as useAdmin, m as useThalamus } from './index-C5rsqdqK.js';
export { APIKeyManager, APIKeyManagerProps, LoginButton, LoginButtonProps, OrgManager, OrgManagerProps, OrgSwitcher, OrgSwitcherProps, RegisterButton, RegisterButtonProps, StatusBadge, UserCreateForm, UserCreateFormProps, UserMenu, UserMenuProps, UserTable, UserTableProps } from './components/index.js';
import React from 'react';
import { T as ThalamusConfig } from './index-BnHWPrKX.js';

interface ThalamusPanelProps {
    config: ThalamusConfig;
    onNavigate?: (view: string) => void;
}
declare function ThalamusPanel({ config, onNavigate }: ThalamusPanelProps): React.JSX.Element;

export { ThalamusPanel, type ThalamusPanelProps };
