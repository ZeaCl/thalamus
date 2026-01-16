/**
 * Login API Route
 *
 * Redirects user to Thalamus authorization page
 */

import { NextRequest, NextResponse } from 'next/server'
import { thalamus } from '@/lib/thalamus'
import { cookies } from 'next/headers'

export async function GET(request: NextRequest) {
  // Generate random state for CSRF protection
  const state = crypto.randomUUID()

  // Store state in cookie for validation in callback
  cookies().set('oauth_state', state, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 10, // 10 minutes
  })

  // Generate authorization URL
  const authUrl = thalamus.auth.getAuthorizationUrl({
    scope: ['openid', 'profile', 'email'],
    state,
  })

  return NextResponse.redirect(authUrl)
}
