import { describe, it, expect } from 'vitest'
import { ThalamusClient } from '../ThalamusClient'

describe('ThalamusClient', () => {
  const config = {
    clientId: 'test_client_id',
    clientSecret: 'test_client_secret',
    redirectUri: 'http://localhost:3000/callback',
    baseUrl: 'http://localhost:4000',
  }

  it('should create a client instance', () => {
    const client = new ThalamusClient(config)
    expect(client).toBeDefined()
  })

  it('should have auth module', () => {
    const client = new ThalamusClient(config)
    expect(client.auth).toBeDefined()
  })

  it('should have tokens module', () => {
    const client = new ThalamusClient(config)
    expect(client.tokens).toBeDefined()
  })

  it('should throw error if clientId is missing', () => {
    expect(() => {
      new ThalamusClient({
        ...config,
        clientId: '',
      })
    }).toThrow()
  })

  it('should throw error if redirectUri is missing', () => {
    expect(() => {
      new ThalamusClient({
        ...config,
        redirectUri: '',
      })
    }).toThrow()
  })

  it('should throw error if baseUrl is missing', () => {
    expect(() => {
      new ThalamusClient({
        ...config,
        baseUrl: '',
      })
    }).toThrow()
  })

  it('should accept default scopes', () => {
    const client = new ThalamusClient({
      ...config,
      defaultScopes: ['openid', 'profile', 'email'],
    })
    expect(client).toBeDefined()
  })
})
