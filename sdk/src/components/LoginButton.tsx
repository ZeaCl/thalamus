'use client'

import React from 'react'
import { useThalamus } from '../hooks/useThalamus'
import type { ThalamusConfig } from '../types'

export interface LoginButtonProps {
  /** Thalamus config (same as ThalamusClient constructor) */
  config: ThalamusConfig
  /** Storage key (default: 'thalamus_auth') */
  storageKey?: string
  /** Button label */
  label?: string
  /** Scopes to request */
  scopes?: string[]
  /** CSS class */
  className?: string
  /** Button style overrides */
  style?: React.CSSProperties
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
export function LoginButton({
  config,
  storageKey = 'thalamus_auth',
  label = 'Login with ZEA',
  scopes,
  className,
  style,
}: LoginButtonProps) {
  const { login, isAuthenticated, isLoading, error } = useThalamus({ ...config, storageKey })

  if (isLoading) return <span style={{ color: '#8b949e', fontSize: 14 }}>Loading...</span>
  if (isAuthenticated) return null

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
      <button
        onClick={() => login({ scope: scopes })}
        className={className}
        style={{
          padding: '12px 32px',
          borderRadius: 8,
          border: 'none',
          cursor: 'pointer',
          background: '#238636',
          color: '#fff',
          fontSize: 16,
          fontWeight: 600,
          fontFamily: 'system-ui, sans-serif',
          ...style,
        }}
      >
        {label}
      </button>
      {error && <span style={{ color: '#ff7b72', fontSize: 12 }}>{error}</span>}
    </div>
  )
}
