'use client'

import React, { useState } from 'react'
import { ThalamusClient } from '../client/ThalamusClient'
import type { ThalamusConfig, User, AgentConfig } from '../types'

export interface UserCreateFormProps {
  config: ThalamusConfig
  onCreated?: (user: User) => void
  className?: string
}

export function UserCreateForm({ config, onCreated, className }: UserCreateFormProps) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [name, setName] = useState('')
  const [isAgent, setIsAgent] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError('')
    try {
      const client = new ThalamusClient(config)
      const user = await client.admin.createUser({ email, password, name, is_agent: isAgent })
      setEmail(''); setPassword(''); setName(''); setIsAgent(false)
      onCreated?.(user)
    } catch (err: any) { setError(err.message) }
    setLoading(false)
  }

  return (
    <form onSubmit={handleSubmit} className={className} style={{ display: 'flex', flexDirection: 'column', gap: 12, fontFamily: 'system-ui, sans-serif' }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <input required placeholder="Email" type="email" value={email} onChange={e => setEmail(e.target.value)} className="th-input" />
        <input required placeholder="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} className="th-input" minLength={8} />
        <input placeholder="Name (optional)" value={name} onChange={e => setName(e.target.value)} className="th-input" />
        <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: '#656d76', cursor: 'pointer' }}>
          <input type="checkbox" checked={isAgent} onChange={e => setIsAgent(e.target.checked)} /> Is Agent
        </label>
      </div>
      {error && <div style={{ padding: '8px 12px', background: 'rgba(248, 81, 73, 0.1)', border: '1px solid rgba(248, 81, 73, 0.4)', borderRadius: 6, color: '#f85149', fontSize: 12 }}>{error}</div>}
      <button type="submit" disabled={loading} className="th-btn th-btn--primary" style={{ alignSelf: 'flex-start' }}>
        {loading ? 'Creating...' : 'Create User'}
      </button>
    </form>
  )
}

// ── User Table ──

export interface UserTableProps {
  users: User[]
  loading?: boolean
  error?: string | null
  className?: string
}

export function UserTable({ users, loading, error, className }: UserTableProps) {
  if (loading) return <p style={{ color: '#656d76', fontSize: 13 }}>Loading...</p>
  if (error) return <div style={{ padding: '8px 12px', background: '#fff0f0', borderRadius: 6, color: '#c00', fontSize: 12 }}>{error}</div>
  if (users.length === 0) return <p style={{ color: '#656d76', fontSize: 13 }}>No users found.</p>

  return (
    <div className={className} style={{ border: '1px solid var(--th-border, #30363d)', borderRadius: 8, overflow: 'hidden' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13, color: 'var(--th-text, #e6edf3)' }}>
        <thead>
          <tr style={{ background: 'var(--th-bg, #0d1117)', textAlign: 'left', borderBottom: '1px solid var(--th-border, #30363d)' }}>
            <th style={{ padding: '8px 16px', fontWeight: 600, color: 'var(--th-text-muted, #8b949e)' }}>Name</th>
            <th style={{ padding: '8px 16px', fontWeight: 600, color: 'var(--th-text-muted, #8b949e)' }}>Email</th>
            <th style={{ padding: '8px 16px', fontWeight: 600, color: 'var(--th-text-muted, #8b949e)' }}>Status</th>
            <th style={{ padding: '8px 16px', fontWeight: 600, color: 'var(--th-text-muted, #8b949e)' }}>Agent</th>
          </tr>
        </thead>
        <tbody>
          {users.map(u => (
            <tr key={u.id} style={{ borderBottom: '1px solid var(--th-border, #30363d)', background: 'transparent' }}>
              <td style={{ padding: '8px 16px' }}>{u.name || '—'}</td>
              <td style={{ padding: '8px 16px', color: '#58a6ff' }}>{u.email}</td>
              <td style={{ padding: '8px 16px' }}>
                <StatusBadge status={u.status} />
              </td>
              <td style={{ padding: '8px 16px' }}>{u.is_agent ? '🤖' : '👤'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

// ── Status Badge ──

export function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, { bg: string; color: string; border: string }> = {
    active: { bg: 'rgba(35, 134, 54, 0.1)', color: '#3fb950', border: 'rgba(63, 185, 80, 0.4)' },
    inactive: { bg: 'rgba(139, 148, 158, 0.1)', color: '#8b949e', border: 'rgba(139, 148, 158, 0.4)' },
    suspended: { bg: 'rgba(248, 81, 73, 0.1)', color: '#f85149', border: 'rgba(248, 81, 73, 0.4)' },
  }
  const c = colors[status] || colors.inactive
  return (
    <span style={{ padding: '2px 8px', borderRadius: 10, fontSize: 11, background: c.bg, color: c.color, border: `1px solid ${c.border}` }}>
      {status || 'unknown'}
    </span>
  )
}
