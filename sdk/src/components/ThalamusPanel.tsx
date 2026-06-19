'use client'

import React, { useState } from 'react'
import type { ThalamusConfig } from '../types'

export interface ThalamusPanelProps {
  config: ThalamusConfig
  onNavigate?: (view: string) => void
}

type View = 'users' | 'users-add' | 'orgs' | 'orgs-add' | 'apikeys'

const Z = {
  bg: '#0d1117', b1: '#161b22', bc: '#21262d',
  tx: '#e6edf3', mu: '#8b949e', pr: '#58a6ff',
  ha: '#484f58',
}

export function ThalamusPanel({ config, onNavigate }: ThalamusPanelProps) {
  const [view, setView] = useState<View>('users')

  const handleNav = (v: View) => {
    setView(v)
    onNavigate?.(v)
  }

  const navItem = (v: View, label: string, icon: string) => (
    <button
      onClick={() => handleNav(v)}
      style={{
        display: 'flex', alignItems: 'center', gap: 8, width: '100%',
        padding: '6px 16px', border: 'none', cursor: 'pointer',
        background: view === v ? `${Z.pr}15` : 'transparent',
        color: view === v ? Z.pr : Z.mu,
        fontSize: 13, fontFamily: 'system-ui, sans-serif', textAlign: 'left',
      }}
    >
      <span style={{ fontSize: 14, width: 20, textAlign: 'center' }}>{icon}</span>
      {label}
    </button>
  )

  return (
    <div>
      {navItem('users', 'Users & Agents', '👤')}
      {navItem('orgs', 'Organizations', '🏢')}
      {navItem('apikeys', 'API Keys', '🔑')}
    </div>
  )
}
