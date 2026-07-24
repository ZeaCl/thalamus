'use client'

import React, { useState } from 'react'
import type { ThalamusConfig } from '../types'

export interface AgentSkillsManagerProps {
  config: ThalamusConfig
  className?: string
}

export function AgentSkillsManager({ config, className }: AgentSkillsManagerProps) {
  const [activeTab, setActiveTab] = useState('active')

  const skills = [
    { id: '1', name: 'Code Analysis', description: 'Analyze PRs and provide inline feedback.', status: 'active', icon: 'M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4' },
    { id: '2', name: 'DB Query Optimization', description: 'Suggest indexes and optimize slow queries.', status: 'active', icon: 'M4 4h16v16H4z M4 9h16 M4 14h16' },
    { id: '3', name: 'Security Audit', description: 'Scan for vulnerable dependencies and secrets.', status: 'inactive', icon: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z' },
  ]

  const filtered = skills.filter(s => s.status === activeTab)

  return (
    <div className={`th-container ${className || ''}`}>
      <div style={{ display: 'flex', gap: '16px', marginBottom: '24px', borderBottom: '1px solid var(--th-border)' }}>
        <button 
          onClick={() => setActiveTab('active')}
          style={{ background: 'none', border: 'none', borderBottom: activeTab === 'active' ? '2px solid var(--th-primary)' : '2px solid transparent', color: activeTab === 'active' ? 'var(--th-text)' : 'var(--th-text-muted)', padding: '8px 4px', cursor: 'pointer', fontSize: '14px', fontWeight: 500 }}
        >
          Active Skills
        </button>
        <button 
          onClick={() => setActiveTab('inactive')}
          style={{ background: 'none', border: 'none', borderBottom: activeTab === 'inactive' ? '2px solid var(--th-primary)' : '2px solid transparent', color: activeTab === 'inactive' ? 'var(--th-text)' : 'var(--th-text-muted)', padding: '8px 4px', cursor: 'pointer', fontSize: '14px', fontWeight: 500 }}
        >
          Available to Install
        </button>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        {filtered.map(skill => (
          <div key={skill.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px', background: 'var(--th-surface, #161b22)', border: '1px solid var(--th-border)', borderRadius: 'var(--th-radius, 8px)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{ width: '40px', height: '40px', borderRadius: '8px', background: 'var(--th-bg)', border: '1px solid var(--th-border)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--th-primary)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d={skill.icon} />
                </svg>
              </div>
              <div>
                <h4 style={{ margin: '0 0 4px 0', color: 'var(--th-text)', fontSize: '15px' }}>{skill.name}</h4>
                <p style={{ margin: 0, color: 'var(--th-text-muted)', fontSize: '13px' }}>{skill.description}</p>
              </div>
            </div>
            <div>
              {activeTab === 'active' ? (
                <button className="th-btn th-btn--ghost" style={{ color: 'var(--th-text-muted)' }}>Configure</button>
              ) : (
                <button className="th-btn th-btn--primary">Install Skill</button>
              )}
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <div style={{ padding: '32px', textAlign: 'center', color: 'var(--th-text-muted)', fontSize: '14px', border: '1px dashed var(--th-border)', borderRadius: 'var(--th-radius, 8px)' }}>
            No skills found in this category.
          </div>
        )}
      </div>
    </div>
  )
}
