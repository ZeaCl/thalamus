'use client'

import React, { useState, useEffect } from 'react'
import type { User } from '../types'

export interface APIKeyManagerProps {
  /** Base URL of the service that manages API keys (e.g. Soma, or Thalamus itself) */
  baseUrl: string
  /** Storage key for the auth token (default: 'thalamus_auth') */
  authStorageKey?: string
  /** Label for the create button */
  label?: string
  className?: string
}

interface APIKey {
  api_key: string
  prefix: string
  created: string
}

/**
 * Drop-in API Key generator and manager.
 *
 * @example
 * ```tsx
 * <APIKeyManager baseUrl="http://soma.zea.localhost" />
 * ```
 */
export function APIKeyManager({ baseUrl, authStorageKey = 'thalamus_auth', label = '+ Generate API Key', className }: APIKeyManagerProps) {
  const [keys, setKeys] = useState<APIKey[]>([])
  const [newKey, setNewKey] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const token = typeof window !== 'undefined' ? (() => {
    try { const s = localStorage.getItem(authStorageKey); return s ? JSON.parse(s).accessToken : null } catch { return null }
  })() : null

  useEffect(() => {
    if (!token) return
    const controller = new AbortController()
    
    fetch(`${baseUrl}/api/personal-access-tokens`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: controller.signal
    })
      .then(res => res.json())
      .then(data => {
        if (data.data) {
          // Map backend response correctly based on standard Elixir JSON:API or similar
          setKeys(data.data.map((k: any) => ({
            api_key: k.api_key || k.id, 
            prefix: k.token_prefix || k.prefix || 'zpat_',
            created: k.inserted_at || k.created_at || k.created || new Date().toISOString()
          })))
        }
      })
      .catch(e => {
        if (e.name !== 'AbortError') console.error('Failed to load API keys:', e)
      })

    return () => controller.abort()
  }, [baseUrl, token])

  const createKey = async () => {
    setLoading(true); setError('')
    try {
      const res = await fetch(`${baseUrl}/api/personal-access-tokens`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ name: `key-${Date.now()}`, scopes: ['api:read', 'api:write'] }),
      })
      const data = await res.json()
      if (data.api_key) {
        setNewKey(data.api_key)
        setKeys(prev => [...prev, { api_key: data.api_key, prefix: data.prefix, created: new Date().toISOString() }])
      } else setError(data.error || 'Failed to create key')
    } catch (e: any) { setError(e.message) }
    setLoading(false)
  }

  const copyKey = (key: string) => { navigator.clipboard?.writeText(key) }

  return (
    <div className={className} style={{ fontFamily: 'system-ui, sans-serif' }}>
      {error && <div style={{ padding: '8px 12px', background: '#fff0f0', borderRadius: 6, color: '#c00', marginBottom: 12, fontSize: 12 }}>{error}</div>}

      <button onClick={createKey} disabled={loading} style={{
        padding: '8px 20px', borderRadius: 6, border: 'none', cursor: 'pointer',
        background: '#238636', color: '#fff', fontSize: 13, fontWeight: 600,
        opacity: loading ? 0.7 : 1, fontFamily: 'inherit',
      }}>
        {loading ? 'Generating...' : label}
      </button>

      {newKey && (
        <div style={{ marginTop: 16, padding: '12px 16px', background: '#f0fff0', borderRadius: 8, border: '1px solid #2ea44f' }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: '#2ea44f', marginBottom: 6 }}>✅ Key created — copy it now</div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <code style={{ flex: 1, padding: '8px 12px', background: '#fff', borderRadius: 4, fontSize: 11, fontFamily: 'monospace', wordBreak: 'break-all', userSelect: 'all' }}>{newKey}</code>
            <button onClick={() => copyKey(newKey)} style={{ padding: '6px 12px', borderRadius: 4, border: '1px solid #2ea44f', background: '#dafbe1', color: '#1a7f37', cursor: 'pointer', fontSize: 11, fontFamily: 'inherit' }}>Copy</button>
          </div>
        </div>
      )}

      {keys.length > 0 && (
        <div style={{ marginTop: 20 }}>
          <div style={{ fontSize: 12, fontWeight: 600, marginBottom: 8 }}>Existing keys ({keys.length})</div>
          {keys.map((k, i) => (
            <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #eee', fontSize: 11, fontFamily: 'monospace', color: '#656d76' }}>
              {k.prefix}...{k.api_key?.slice(-8)} · {new Date(k.created).toLocaleDateString()}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
