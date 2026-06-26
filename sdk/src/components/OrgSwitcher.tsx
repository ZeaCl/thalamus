'use client'

import React, { useState, useEffect } from 'react'
import { ThalamusClient } from '../client/ThalamusClient'
import type { ThalamusConfig } from '../types'

export interface OrgSwitcherProps {
  config: ThalamusConfig
  /** Called when user switches org */
  onSwitch?: (orgId: string) => void
  className?: string
  style?: React.CSSProperties
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
export function OrgSwitcher({ config, onSwitch, className, style }: OrgSwitcherProps) {
  const [orgs, setOrgs] = useState<{ id: string; name: string }[]>([])
  const [selected, setSelected] = useState(() => {
    try {
      const authStr = typeof window !== 'undefined' ? localStorage.getItem('thalamus_auth') : null
      if (authStr) {
        const auth = JSON.parse(authStr)
        return auth.user?.organization_id || ''
      }
    } catch (e) {
      console.error(e)
    }
    return ''
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const client = new ThalamusClient(config)
    client.admin.listOrganizations()
      .then(o => { setOrgs(o); setLoading(false) })
      .catch(() => setLoading(false))
  }, [config.baseUrl])

  if (loading) return null
  if (orgs.length === 0) return null

  return (
    <select
      className={`th-select ${className || ''}`}
      value={selected}
      onChange={e => { setSelected(e.target.value); onSwitch?.(e.target.value) }}
      style={style}
    >
      <option value="">Select org...</option>
      {orgs.map(org => (
        <option key={org.id} value={org.id}>{org.name}</option>
      ))}
    </select>
  )
}
