'use client'

import React from 'react'
import type { ThalamusConfig } from '../types'

export interface AuditLogViewerProps {
  config: ThalamusConfig
  className?: string
}

export function AuditLogViewer({ config, className }: AuditLogViewerProps) {
  const logs = [
    { id: '1', action: 'API Key Created', actor: 'carlos@zea.cl', target: 'Token: zpat_8x9...', timestamp: '2 mins ago', status: 'success' },
    { id: '2', action: 'User Invited', actor: 'admin@zea.cl', target: 'dev@zea.cl', timestamp: '1 hour ago', status: 'success' },
    { id: '3', action: 'Failed Login', actor: 'unknown', target: 'admin@zea.cl', timestamp: '3 hours ago', status: 'failed' },
    { id: '4', action: 'Role Updated', actor: 'carlos@zea.cl', target: 'Role: Editor -> Admin', timestamp: '1 day ago', status: 'success' },
    { id: '5', action: 'Integration Connected', actor: 'carlos@zea.cl', target: 'GitHub App', timestamp: '2 days ago', status: 'success' },
  ]

  return (
    <div className={`th-table-container ${className || ''}`} style={{ border: '1px solid var(--th-border)', borderRadius: 'var(--th-radius, 8px)', overflow: 'hidden' }}>
      <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--th-border)', background: 'var(--th-surface, #161b22)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h3 style={{ margin: 0, fontSize: '15px', color: 'var(--th-text)' }}>Security Events</h3>
        <button className="th-btn th-btn--ghost" style={{ padding: '4px 12px' }}>
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ marginRight: '6px' }}><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          Export CSV
        </button>
      </div>
      <table className="th-table" style={{ margin: 0, width: '100%', borderCollapse: 'collapse' }}>
        <thead style={{ background: 'var(--th-bg)' }}>
          <tr>
            <th style={{ padding: '12px 20px', textAlign: 'left', color: 'var(--th-text-muted)', fontWeight: 500, fontSize: '12px', borderBottom: '1px solid var(--th-border)' }}>Event</th>
            <th style={{ padding: '12px 20px', textAlign: 'left', color: 'var(--th-text-muted)', fontWeight: 500, fontSize: '12px', borderBottom: '1px solid var(--th-border)' }}>Actor</th>
            <th style={{ padding: '12px 20px', textAlign: 'left', color: 'var(--th-text-muted)', fontWeight: 500, fontSize: '12px', borderBottom: '1px solid var(--th-border)' }}>Target</th>
            <th style={{ padding: '12px 20px', textAlign: 'left', color: 'var(--th-text-muted)', fontWeight: 500, fontSize: '12px', borderBottom: '1px solid var(--th-border)' }}>Time</th>
            <th style={{ padding: '12px 20px', textAlign: 'right', color: 'var(--th-text-muted)', fontWeight: 500, fontSize: '12px', borderBottom: '1px solid var(--th-border)' }}>Status</th>
          </tr>
        </thead>
        <tbody>
          {logs.map((log) => (
            <tr key={log.id} style={{ borderBottom: '1px solid var(--th-border)', transition: 'background 0.2s', cursor: 'pointer' }} onMouseEnter={e => e.currentTarget.style.background = 'var(--th-surface)'} onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
              <td style={{ padding: '12px 20px', color: 'var(--th-text)', fontSize: '13px', fontWeight: 500 }}>{log.action}</td>
              <td style={{ padding: '12px 20px', color: 'var(--th-text-muted)', fontSize: '13px', fontFamily: 'monospace' }}>{log.actor}</td>
              <td style={{ padding: '12px 20px', color: 'var(--th-text-muted)', fontSize: '13px' }}>{log.target}</td>
              <td style={{ padding: '12px 20px', color: 'var(--th-text-muted)', fontSize: '13px' }}>{log.timestamp}</td>
              <td style={{ padding: '12px 20px', textAlign: 'right' }}>
                <span className={`th-badge ${log.status === 'success' ? 'th-badge--active' : 'th-badge--inactive'}`} style={{ 
                  color: log.status === 'success' ? '#3fb950' : '#f85149',
                  background: log.status === 'success' ? 'rgba(46, 160, 67, 0.15)' : 'rgba(248, 81, 73, 0.15)',
                  border: `1px solid ${log.status === 'success' ? 'rgba(46, 160, 67, 0.4)' : 'rgba(248, 81, 73, 0.4)'}`
                }}>
                  {log.status}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
