'use client'

import React from 'react'
import type { ThalamusConfig } from '../types'

export interface RegisterButtonProps {
  config: ThalamusConfig
  /** Organization name — Thalamus creates it automatically on registration */
  orgName?: string
  /** App origin for auto-CORS + OAuth client registration */
  appOrigin?: string
  label?: string
  className?: string
  style?: React.CSSProperties
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
export function RegisterButton({ config, orgName, appOrigin, label = 'Create Account', className, style }: RegisterButtonProps) {
  const handleClick = () => {
    const authParams = new URLSearchParams({
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      response_type: 'code',
      scope: (config.defaultScopes || ['openid', 'profile', 'email']).join(' '),
      state: crypto.randomUUID(),
    })
    if (orgName) authParams.set('org_name', orgName)
    if (appOrigin) authParams.set('app_origin', appOrigin)
    const returnTo = `/oauth/authorize?${authParams.toString()}`
    window.location.href = `${config.baseUrl}/register?return_to=${encodeURIComponent(returnTo)}`
  }

  return (
    <button onClick={handleClick} className={className} style={{ padding:'12px 32px', borderRadius:8, border:'1px solid #30363d', cursor:'pointer', background:'transparent', color:'#e6edf3', fontSize:16, fontWeight:600, fontFamily:'system-ui, sans-serif', ...style }}>
      {label}
    </button>
  )
}
