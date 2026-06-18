'use client'

import React, { useState, useEffect } from 'react'
import { ThalamusClient } from '../client/ThalamusClient'
import type { ThalamusConfig, Organization } from '../types'

export interface OrgManagerProps {
  config: ThalamusConfig
  className?: string
}

export function OrgManager({ config, className }: OrgManagerProps) {
  const [orgs, setOrgs] = useState<Organization[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const client = new ThalamusClient(config)
    client.admin.listOrganizations()
      .then(o => { setOrgs(o); setLoading(false) })
      .catch(e => { setError(e.message); setLoading(false) })
  }, [config.baseUrl, config.clientId, config.redirectUri])

  if (loading) return <p style={{ color: '#656d76', fontSize: 13 }}>Loading...</p>
  if (error) return <div style={{ padding: '8px 12px', background: '#fff0f0', borderRadius: 6, color: '#c00', fontSize: 12 }}>{error}</div>
  if (orgs.length === 0) return <p style={{ color: '#656d76', fontSize: 13 }}>No organizations.</p>

  return (
    <div className={className} style={{ display: 'flex', flexDirection: 'column', gap: 12, fontFamily: 'system-ui, sans-serif' }}>
      {orgs.map(org => (
        <div key={org.id} style={{ padding: '16px', border: '1px solid #d0d7de', borderRadius: 8 }}>
          <div style={{ fontWeight: 600, fontSize: 15 }}>{org.name}</div>
          <div style={{ fontSize: 12, color: '#656d76', marginTop: 4 }}>
            Domains: {(org.domains || []).join(', ') || 'none'}
          </div>
        </div>
      ))}
    </div>
  )
}
