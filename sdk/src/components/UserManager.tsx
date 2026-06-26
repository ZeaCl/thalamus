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
    <form onSubmit={handleSubmit} className={`th-form ${className || ''}`}>
      <div className="th-form-grid">
        <input required placeholder="Email" type="email" value={email} onChange={e => setEmail(e.target.value)} className="th-input" />
        <input required placeholder="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} className="th-input" minLength={8} />
        <input placeholder="Name (optional)" value={name} onChange={e => setName(e.target.value)} className="th-input" />
        <label className="th-checkbox-label">
          <input type="checkbox" checked={isAgent} onChange={e => setIsAgent(e.target.checked)} /> Is Agent
        </label>
      </div>
      {error && <div className="th-alert">{error}</div>}
      <div>
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
            <th>Status</th>
            <th>Agent</th>
          </tr>
        </thead>
        <tbody>
          {users.map(u => (
            <tr key={u.id}>
              <td>{u.name || '—'}</td>
              <td className="th-text-accent">{u.email}</td>
              <td>
                <StatusBadge status={u.status} />
              </td>
              <td>{u.is_agent ? '🤖' : '👤'}</td>
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
