import React from 'react';
import { T as ThalamusConfig, U as UserInfo, a as User } from '../index-BnHWPrKX.js';

interface LoginButtonProps {
    /** Thalamus config (same as ThalamusClient constructor) */
    config: ThalamusConfig;
    /** Storage key (default: 'thalamus_auth') */
    storageKey?: string;
    /** Button label */
    label?: string;
    /** Scopes to request */
    scopes?: string[];
    /** CSS class */
    className?: string;
    /** Button style overrides */
    style?: React.CSSProperties;
}
/**
 * Drop-in login button with full OAuth2 PKCE flow.
 *
 * @example
 * ```tsx
 * <LoginButton
 *   config={{
 *     clientId: 'my_app',
 *     redirectUri: 'http://localhost:5173/callback',
 *     baseUrl: 'http://auth.zea.localhost',
 *   }}
 * />
 * ```
 */
declare function LoginButton({ config, storageKey, label, scopes, className, style, }: LoginButtonProps): React.JSX.Element | null;

interface RegisterButtonProps {
    config: ThalamusConfig;
    /** Organization name — Thalamus creates it automatically on registration */
    orgName?: string;
    /** App origin for auto-CORS + OAuth client registration */
    appOrigin?: string;
    label?: string;
    className?: string;
    style?: React.CSSProperties;
}
/**
 * Drop-in register button. Redirects to Thalamus /register page.
 * Passes orgName + appOrigin so Thalamus can auto-create org, OAuth client, and CORS.
 *
 * @example
 * ```tsx
 * // New developer — creates org + app config at the same time
 * <RegisterButton
 *   config={{ clientId:'my_app', redirectUri:'http://localhost:5173/callback', baseUrl:'http://auth.zea.localhost' }}
 *   orgName="My Startup"
 *   appOrigin="http://localhost:5173"
 * />
 *
 * // Returning developer — just login, Thalamus asks if they want to register a new app
 * <RegisterButton
 *   config={{ clientId:'my_app2', redirectUri:'http://localhost:5299/callback', baseUrl:'http://auth.zea.localhost' }}
 * />
 * ```
 */
declare function RegisterButton({ config, orgName, appOrigin, label, className, style }: RegisterButtonProps): React.JSX.Element;

interface UserMenuProps {
    config: ThalamusConfig;
    storageKey?: string;
    /** Render custom user info */
    renderUser?: (user: UserInfo) => React.ReactNode;
    className?: string;
}
/**
 * User badge with logout. Shows nothing if not authenticated.
 *
 * @example
 * ```tsx
 * <UserMenu
 *   config={{
 *     clientId: 'my_app',
 *     redirectUri: 'http://localhost:5173/callback',
 *     baseUrl: 'http://auth.zea.localhost',
 *   }}
 * />
 * ```
 */
declare function UserMenu({ config, storageKey, renderUser, className }: UserMenuProps): React.JSX.Element | null;

interface APIKeyManagerProps {
    /** Base URL of the service that manages API keys (e.g. Soma, or Thalamus itself) */
    baseUrl: string;
    /** Storage key for the auth token (default: 'thalamus_auth') */
    authStorageKey?: string;
    /** Label for the create button */
    label?: string;
    className?: string;
}
/**
 * Drop-in API Key generator and manager.
 *
 * @example
 * ```tsx
 * <APIKeyManager baseUrl="http://soma.zea.localhost" />
 * ```
 */
declare function APIKeyManager({ baseUrl, authStorageKey, label, className }: APIKeyManagerProps): React.JSX.Element;

interface OrgSwitcherProps {
    config: ThalamusConfig;
    /** Called when user switches org */
    onSwitch?: (orgId: string) => void;
    className?: string;
}
/**
 * Organization switcher dropdown.
 *
 * @example
 * ```tsx
 * <OrgSwitcher
 *   config={{ clientId: 'my_app', redirectUri: '/callback', baseUrl: 'http://auth.zea.localhost' }}
 *   onSwitch={(orgId) => console.log('Switched to', orgId)}
 * />
 * ```
 */
declare function OrgSwitcher({ config, onSwitch, className }: OrgSwitcherProps): React.JSX.Element | null;

interface OrgManagerProps {
    config: ThalamusConfig;
    className?: string;
}
declare function OrgManager({ config, className }: OrgManagerProps): React.JSX.Element;

interface UserCreateFormProps {
    config: ThalamusConfig;
    onCreated?: (user: User) => void;
    className?: string;
}
declare function UserCreateForm({ config, onCreated, className }: UserCreateFormProps): React.JSX.Element;
interface UserTableProps {
    users: User[];
    loading?: boolean;
    error?: string | null;
    className?: string;
}
declare function UserTable({ users, loading, error, className }: UserTableProps): React.JSX.Element;
declare function StatusBadge({ status }: {
    status: string;
}): React.JSX.Element;

export { APIKeyManager, type APIKeyManagerProps, LoginButton, type LoginButtonProps, OrgManager, type OrgManagerProps, OrgSwitcher, type OrgSwitcherProps, RegisterButton, type RegisterButtonProps, StatusBadge, UserCreateForm, type UserCreateFormProps, UserMenu, type UserMenuProps, UserTable, type UserTableProps };
