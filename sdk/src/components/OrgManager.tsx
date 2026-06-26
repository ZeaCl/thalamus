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

  if (loading) return <p className="th-loading">Loading...</p>
  if (error) return <div className="th-alert">{error}</div>
  if (orgs.length === 0) return <p className="th-empty">No organizations.</p>

  return (
    <div className={`th-list ${className || ''}`}>
      {orgs.map(org => (
        <div key={org.id} className="th-card">
          <div className="th-card-title">{org.name}</div>
          <div className="th-card-desc">
            Domains: {(org.domains || []).join(', ') || 'none'}
          </div>
        </div>
      ))}
    </div>
  )
}
