'use client'

import React from 'react'
import { useThalamus } from '../hooks/useThalamus'
import type { ThalamusConfig, UserInfo } from '../types'

export interface UserMenuProps {
  config: ThalamusConfig
  storageKey?: string
  /** Render custom user info */
  renderUser?: (user: UserInfo) => React.ReactNode
  className?: string
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
export function UserMenu({ config, storageKey = 'thalamus_auth', renderUser, className }: UserMenuProps) {
  const { user, logout, isAuthenticated, isLoading, token } = useThalamus({ ...config, storageKey })

  if (isLoading || !isAuthenticated || !user) return null

  const initials = user.name
    ? user.name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
    : (user.email || user.sub).slice(0, 2).toUpperCase()

  return (
    <div className={className} style={{ display: 'flex', alignItems: 'center', gap: 10, fontFamily: 'system-ui, sans-serif' }}>
      {renderUser ? renderUser(user) : (
        <>
          <div style={{
            width: 28, height: 28, borderRadius: '50%',
            background: '#238636', color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 11, fontWeight: 700, flexShrink: 0,
          }}>
            {user.picture ? <img src={user.picture} alt="" style={{ width: 28, height: 28, borderRadius: '50%' }} /> : initials}
          </div>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: '#e6edf3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {user.name || user.email || user.sub}
            </div>
          </div>
        </>
      )}
      <button
        onClick={logout}
        style={{
          background: 'none', border: '1px solid #30363d',
          color: '#8b949e', padding: '4px 10px', borderRadius: 6,
          cursor: 'pointer', fontSize: 11, fontFamily: 'inherit',
        }}
      >
        Logout
      </button>
    </div>
  )
}
