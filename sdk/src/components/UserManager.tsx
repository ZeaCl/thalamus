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
  const [confirmPassword, setConfirmPassword] = useState('')
  const [name, setName] = useState('')
  const [isAgent, setIsAgent] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [showPassword, setShowPassword] = useState(false)

  const generatePassword = () => {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    let pass = ''
    for (let i = 0; i < 16; i++) {
      pass += chars.charAt(Math.floor(Math.random() * chars.length))
    }
    setPassword(pass)
    setConfirmPassword(pass)
    setShowPassword(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (password !== confirmPassword) {
      setError('Passwords do not match')
      return
    }
    setLoading(true); setError('')
    try {
      const client = new ThalamusClient(config)
      const user = await client.admin.createUser({ email, password, name, is_agent: isAgent })
      setEmail(''); setPassword(''); setConfirmPassword(''); setName(''); setIsAgent(false); setShowPassword(false)
      onCreated?.(user)
    } catch (err: any) { setError(err.message) }
    setLoading(false)
  }

  return (
    <form onSubmit={handleSubmit} className={`th-form ${className || ''}`}>
      <div className="th-form-grid">
        <input required placeholder="Email" type="email" value={email} onChange={e => setEmail(e.target.value)} className="th-input" />
        <input placeholder="Name (optional)" value={name} onChange={e => setName(e.target.value)} className="th-input" />
        
        <div style={{ position: 'relative', display: 'flex', gap: '8px' }}>
          <input required placeholder="Password" type={showPassword ? 'text' : 'password'} value={password} onChange={e => setPassword(e.target.value)} className="th-input" minLength={8} style={{ flex: 1, minWidth: 0 }} />
          <button type="button" onClick={generatePassword} className="th-btn th-btn--ghost" title="Generate Password" style={{ padding: '0 12px' }}>
            🎲
          </button>
        </div>
        
        <input required placeholder="Confirm Password" type={showPassword ? 'text' : 'password'} value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} className="th-input" minLength={8} />

        <select value={isAgent ? 'agent' : 'user'} onChange={e => setIsAgent(e.target.value === 'agent')} className="th-select" style={{ gridColumn: '1 / -1' }}>
          <option value="user">👤 Human User</option>
          <option value="agent">🤖 AI Agent</option>
        </select>
      </div>
      {error && <div className="th-alert">{error}</div>}
      <div style={{ marginTop: '8px' }}>
        <button type="submit" disabled={loading} className="th-btn th-btn--primary">
          {loading ? 'Creating...' : 'Create User'}
        </button>
      </div>
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
  if (loading) return <p className="th-loading">Loading...</p>
  if (error) return <div className="th-alert">{error}</div>
  if (users.length === 0) return <p className="th-empty">No users found.</p>

  return (
    <div className={`th-table-container ${className || ''}`}>
      <table className="th-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
            <th>Organization</th>
            <th>User Type</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {users.map(u => (
            <tr key={u.id}>
              <td>{u.name || '—'}</td>
              <td className="th-text-accent">{u.email}</td>
              <td style={{ color: 'var(--th-text-muted)' }}>{u.organization_id ? u.organization_id.split('-')[0] + '...' : '—'}</td>
              <td>{u.is_agent ? '🤖 Agent' : '👤 User'}</td>
              <td>
                <StatusBadge status={u.status} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

// ── Status Badge ──

export function StatusBadge({ status }: { status: string }) {
  const badgeClass = status ? `th-badge--${status}` : ''
  return (
    <span className={`th-badge ${badgeClass}`}>
      {status || 'unknown'}
    </span>
  )
}
