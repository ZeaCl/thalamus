import { describe, it, expect } from 'vitest'
import { ThalamusClient } from '../../ThalamusClient'

describe('OAuth2', () => {
  const config = {
    clientId: 'test_client_id',
    clientSecret: 'test_client_secret',
    redirectUri: 'http://localhost:3000/callback',
    baseUrl: 'http://localhost:4000',
    defaultScopes: ['openid', 'profile', 'email'],
  }

  const client = new ThalamusClient(config)

  describe('getAuthorizationUrl', () => {
    it('should generate authorization URL with default scopes', () => {
      const url = client.auth.getAuthorizationUrl()

      expect(url).toContain('http://localhost:4000/oauth/authorize')
      expect(url).toContain('response_type=code')
      expect(url).toContain('client_id=test_client_id')
      expect(url).toContain('redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback')
      expect(url).toContain('scope=openid+profile+email')
      expect(url).toContain('state=')
    })

    it('should generate authorization URL with custom state', () => {
      const customState = 'custom-state-123'
      const url = client.auth.getAuthorizationUrl({ state: customState })

      expect(url).toContain(`state=${customState}`)
    })

    it('should generate authorization URL with custom scopes', () => {
      const url = client.auth.getAuthorizationUrl({
        scope: ['openid', 'profile'],
      })

      expect(url).toContain('scope=openid+profile')
    })
  })

  describe('URL validation', () => {
    it('should handle baseUrl without trailing slash', () => {
      const clientNoSlash = new ThalamusClient({
        ...config,
        baseUrl: 'http://localhost:4000',
      })
      const url = clientNoSlash.auth.getAuthorizationUrl()
      expect(url).toContain('http://localhost:4000/oauth/authorize')
    })

    it('should handle baseUrl with trailing slash', () => {
      const clientWithSlash = new ThalamusClient({
        ...config,
        baseUrl: 'http://localhost:4000/',
      })
      const url = clientWithSlash.auth.getAuthorizationUrl()
      expect(url).toContain('http://localhost:4000/oauth/authorize')
    })
  })
})
