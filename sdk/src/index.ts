// Hooks
export { useThalamus } from './hooks/useThalamus'
export type { UseThalamusOptions, UseThalamusReturn } from './hooks/useThalamus'
export { useAdmin } from './hooks/useAdmin'
export type { UseAdminOptions, UseAdminReturn } from './hooks/useAdmin'

// Components
export { LoginButton } from './components/LoginButton'
export type { LoginButtonProps } from './components/LoginButton'
export { RegisterButton } from './components/RegisterButton'
export type { RegisterButtonProps } from './components/RegisterButton'
export { UserMenu } from './components/UserMenu'
export type { UserMenuProps } from './components/UserMenu'
export { UserCreateForm, UserTable, StatusBadge } from './components/UserManager'
export type { UserCreateFormProps, UserTableProps } from './components/UserManager'
export { APIKeyManager } from './components/APIKeyManager'
export type { APIKeyManagerProps } from './components/APIKeyManager'
export { OrgSwitcher } from './components/OrgSwitcher'
export type { OrgSwitcherProps } from './components/OrgSwitcher'
export { OrgManager } from './components/OrgManager'
export type { OrgManagerProps } from './components/OrgManager'

// Client (low-level)
export { ThalamusClient } from './client/ThalamusClient'
export { OAuth2 } from './client/OAuth2'
export { TokenManager } from './client/TokenManager'
export { AdminAPI } from './client/AdminAPI'

// Types
export type {
  ThalamusConfig, TokenResponse, IntrospectionResponse, UserInfo,
  User, Organization, Role, DomainRole, AgentConfig,
  ThalamusError,
} from './types'
