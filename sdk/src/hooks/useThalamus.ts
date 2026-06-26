'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import type { ThalamusConfig, TokenResponse, UserInfo } from '../types'
import { ThalamusClient } from '../client/ThalamusClient'

export interface UseThalamusOptions extends ThalamusConfig {
  /** Storage key for persisting auth (default: 'thalamus_auth') */
  storageKey?: string
}

export interface UseThalamusReturn {
  /** Start OAuth2 PKCE login flow (redirects browser) */
  login: (options?: { scope?: string[] }) => Promise<void>
  /** Clear stored token and reset state */
  logout: () => void
  /** Raw access token */
  token: string | null
  /** Decoded user info */
  user: UserInfo | null
  /** Whether authenticated */
  isAuthenticated: boolean
  /** Whether loading auth state */
  isLoading: boolean
  /** Refresh the access token */
  refreshToken: () => Promise<void>
  /** ThalamusClient instance for direct API calls */
  client: ThalamusClient
  /** Error message if any */
  error: string | null
}

export function useThalamus(options: UseThalamusOptions): UseThalamusReturn {
  const storageKey = options.storageKey || 'thalamus_auth'
  const clientRef = useRef(new ThalamusClient(options))
  const client = clientRef.current

  const [token, setToken] = useState<string | null>(null)
  const [user, setUser] = useState<UserInfo | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // ── Load stored auth on mount ──
  useEffect(() => {
    try {
      const saved = localStorage.getItem(storageKey)
      if (saved) {
        const { accessToken, refreshToken: rt } = JSON.parse(saved)
        setToken(accessToken)
        client.tokens.getUserInfo(accessToken).then(u => setUser(u)).catch(() => {})
      }
    } catch {} finally {
      setIsLoading(false)
    }
  }, [storageKey])

  // ── Handle OAuth callback ──
  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const code = params.get('code')
    const state = params.get('state')
    if (!code || !state) return

    // Immediately remove code from URL to prevent React 18 Strict Mode double-fetching
    window.history.replaceState({}, '', window.location.pathname)

    const savedState = sessionStorage.getItem(`${storageKey}_state`)
    if (state !== savedState) {
      setError('State mismatch — possible CSRF attack')
      return
    }

    const verifier = sessionStorage.getItem(`${storageKey}_verifier`)
    if (!verifier) { setError('Missing code verifier'); return }

    client.auth.exchangeCode({ code, codeVerifier: verifier })
      .then(data => {
        persistAuth(data)
        setToken(data.access_token)
        client.tokens.getUserInfo(data.access_token).then(u => setUser(u)).catch(() => {})
      })
      .catch(err => setError(err.message))
  }, [storageKey])

  // ── Persist auth ──
  const persistAuth = (data: TokenResponse) => {
    localStorage.setItem(storageKey, JSON.stringify({ accessToken: data.access_token, refreshToken: data.refresh_token || null, expiresAt: Date.now() + data.expires_in * 1000 }))
  }

  // ── Login: PKCE + redirect ──
  const login = useCallback(async (opts?: { scope?: string[] }) => {
    setError(null)
    const verifier = client.auth.generateState()
    const challenge = await pkceChallenge(verifier)
    sessionStorage.setItem(`${storageKey}_verifier`, verifier)
    const url = client.auth.getAuthorizationUrl({ scope: opts?.scope, codeChallenge: challenge, codeChallengeMethod: 'S256' })
    sessionStorage.setItem(`${storageKey}_state`, new URL(url).searchParams.get('state') || '')
    window.location.href = url
  }, [storageKey])

  // ── Logout ──
  const logout = useCallback(() => {
    localStorage.removeItem(storageKey)
    setToken(null)
    setUser(null)
  }, [storageKey])

  // ── Global 401 Interceptor ──
  useEffect(() => {
    if (typeof window === 'undefined') return
    const handleUnauthorized = () => logout()
    
    window.addEventListener('thalamus:unauthorized', handleUnauthorized)
    const handleMessage = (e: MessageEvent) => {
      if (e.data?.type === 'thalamus:unauthorized') handleUnauthorized()
    }
    window.addEventListener('message', handleMessage)
    
    return () => {
      window.removeEventListener('thalamus:unauthorized', handleUnauthorized)
      window.removeEventListener('message', handleMessage)
    }
  }, [logout])

  // ── Refresh token ──
  const refreshToken = useCallback(async () => {
    try {
      const saved = localStorage.getItem(storageKey)
      if (!saved) return
      const { refreshToken: rt } = JSON.parse(saved)
      if (!rt) return
      const data = await client.auth.refreshToken({ refreshToken: rt })
      persistAuth(data)
      setToken(data.access_token)
    } catch {}
  }, [storageKey])

  return {
    login, logout, token, user,
    isAuthenticated: !!token,
    isLoading, refreshToken,
    client, error,
  }
}

// ── PKCE helper ──
async function pkceChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder()
  const hash = await crypto.subtle.digest('SHA-256', encoder.encode(verifier))
  return btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
