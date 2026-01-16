/**
 * Thalamus OAuth2 Client Configuration
 *
 * This file configures the Thalamus SDK for authentication
 */

import ThalamusClient from '@zea.cl/thalamus-js'

if (!process.env.THALAMUS_CLIENT_ID) {
  throw new Error('Missing THALAMUS_CLIENT_ID environment variable')
}

if (!process.env.THALAMUS_CLIENT_SECRET) {
  throw new Error('Missing THALAMUS_CLIENT_SECRET environment variable')
}

if (!process.env.THALAMUS_BASE_URL) {
  throw new Error('Missing THALAMUS_BASE_URL environment variable')
}

if (!process.env.NEXTAUTH_URL) {
  throw new Error('Missing NEXTAUTH_URL environment variable')
}

export const thalamus = new ThalamusClient({
  clientId: process.env.THALAMUS_CLIENT_ID,
  clientSecret: process.env.THALAMUS_CLIENT_SECRET,
  redirectUri: `${process.env.NEXTAUTH_URL}/auth/callback`,
  baseUrl: process.env.THALAMUS_BASE_URL,
  defaultScopes: ['openid', 'profile', 'email'],
})
