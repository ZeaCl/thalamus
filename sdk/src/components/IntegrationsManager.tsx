'use client'

import React from 'react'
import type { ThalamusConfig } from '../types'

export interface IntegrationsManagerProps {
  config: ThalamusConfig
  className?: string
}

export function IntegrationsManager({ config, className }: IntegrationsManagerProps) {
  const integrations = [
    { id: 'github', name: 'GitHub', description: 'Sync repositories and trigger CI/CD pipelines.', connected: true },
    { id: 'slack', name: 'Slack', description: 'Send notifications to channels and manage alerts.', connected: false },
    { id: 'aws', name: 'AWS', description: 'Manage cloud resources and deployments.', connected: false },
    { id: 'linear', name: 'Linear', description: 'Sync issues and project tracking.', connected: true },
  ]

  return (
    <div className={`th-container ${className || ''}`} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px' }}>
        {integrations.map(integration => (
          <div key={integration.id} style={{
            padding: '20px',
            borderRadius: 'var(--th-radius, 8px)',
            border: '1px solid var(--th-border)',
            background: 'var(--th-surface, #161b22)',
            display: 'flex',
            flexDirection: 'column',
            gap: '12px'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <div style={{
                  width: '32px', height: '32px', borderRadius: '6px',
                  background: 'var(--th-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                  border: '1px solid var(--th-border)'
                }}>
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--th-text-muted)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"/><path d="M9 18c-4.51 2-5-2-7-2"/></svg>
                </div>
                <h3 style={{ margin: 0, fontSize: '15px', fontWeight: 600, color: 'var(--th-text)' }}>{integration.name}</h3>
              </div>
              <span className={`th-badge ${integration.connected ? 'th-badge--active' : ''}`}>
                {integration.connected ? 'Connected' : 'Disconnected'}
              </span>
            </div>
            <p style={{ margin: 0, fontSize: '13px', color: 'var(--th-text-muted)', lineHeight: '1.4' }}>
              {integration.description}
            </p>
            <div style={{ marginTop: 'auto', paddingTop: '12px' }}>
              <button className={`th-btn ${integration.connected ? 'th-btn--ghost' : 'th-btn--primary'}`} style={{ width: '100%', justifyContent: 'center' }}>
                {integration.connected ? 'Configure' : 'Connect'}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
