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
        
        <div style={{ display: 'flex', gap: '8px' }}>
          <div style={{ position: 'relative', flex: 1, display: 'flex' }}>
            <input required placeholder="Password" type={showPassword ? 'text' : 'password'} value={password} onChange={e => setPassword(e.target.value)} className="th-input" minLength={8} style={{ flex: 1, minWidth: 0, paddingRight: 32 }} />
            <button type="button" onClick={() => setShowPassword(!showPassword)} style={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', color: 'var(--th-text-muted)', cursor: 'pointer', padding: 2, display: 'flex' }}>
              {showPassword ? (
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
              ) : (
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
              )}
            </button>
          </div>
          <button type="button" onClick={generatePassword} className="th-btn th-btn--ghost" title="Generate Password" style={{ padding: '0 12px' }}>
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
          </button>
        </div>
        
        <div style={{ position: 'relative', display: 'flex' }}>
          <input required placeholder="Confirm Password" type={showPassword ? 'text' : 'password'} value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} className="th-input" minLength={8} style={{ flex: 1, minWidth: 0, paddingRight: 32 }} />
          <button type="button" onClick={() => setShowPassword(!showPassword)} style={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', color: 'var(--th-text-muted)', cursor: 'pointer', padding: 2, display: 'flex' }}>
            {showPassword ? (
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
            ) : (
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
            )}
          </button>
        </div>

        <select value={isAgent ? 'agent' : 'user'} onChange={e => setIsAgent(e.target.value === 'agent')} className="th-select" style={{ gridColumn: '1 / -1' }}>
          <option value="user">Human User</option>
          <option value="agent">AI Agent</option>
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
              <td style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '10px 16px' }}>
                {u.is_agent ? (
                  <><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect width="18" height="14" x="3" y="7" rx="2" ry="2"/><path d="M12 7V3"/><path d="M9 3h6"/><path d="M12 11h.01"/><path d="M15 15h.01"/><path d="M9 15h.01"/></svg> Agent</>
                ) : (
                  <><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg> User</>
                )}
              </td>
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
