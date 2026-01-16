import { describe, it, expect } from 'vitest'
import type {
  ThalamusConfig,
  TokenResponse,
  IntrospectionResponse,
  UserInfo,
  ThalamusError
} from '../types'

describe('Types', () => {
  it('should validate ThalamusConfig structure', () => {
    const config: ThalamusConfig = {
      clientId: 'test',
      clientSecret: 'secret',
      redirectUri: 'http://localhost:3000/callback',
      baseUrl: 'http://localhost:4000',
      defaultScopes: ['openid'],
    }

    expect(config.clientId).toBe('test')
    expect(config.defaultScopes).toEqual(['openid'])
  })

  it('should validate TokenResponse structure', () => {
    const tokenResponse: TokenResponse = {
      access_token: 'at_123',
      token_type: 'Bearer',
      expires_in: 3600,
      refresh_token: 'rt_456',
      scope: 'openid profile',
    }

    expect(tokenResponse.token_type).toBe('Bearer')
    expect(tokenResponse.expires_in).toBe(3600)
  })

  it('should validate IntrospectionResponse structure', () => {
    const introspection: IntrospectionResponse = {
      active: true,
      scope: 'openid profile',
      client_id: 'client_123',
      user_id: 'user_456',
      token_type: 'Bearer',
      exp: 1234567890,
      iat: 1234564290,
      nbf: 1234564290,
      sub: 'user_456',
      aud: 'client_123',
      iss: 'http://localhost:4000',
      jti: 'token_id',
    }

    expect(introspection.active).toBe(true)
  })

  it('should validate UserInfo structure', () => {
    const userInfo: UserInfo = {
      sub: 'user_123',
      email: 'user@example.com',
      email_verified: true,
      name: 'John Doe',
      given_name: 'John',
      family_name: 'Doe',
      picture: 'https://example.com/avatar.jpg',
      organization_id: 'org_123',
    }

    expect(userInfo.sub).toBe('user_123')
    expect(userInfo.email_verified).toBe(true)
  })

  it('should validate ThalamusError structure', () => {
    const error: ThalamusError = {
      error: 'invalid_request',
      error_description: 'Missing required parameter',
      status: 400,
    }

    expect(error.error).toBe('invalid_request')
    expect(error.status).toBe(400)
  })
})
