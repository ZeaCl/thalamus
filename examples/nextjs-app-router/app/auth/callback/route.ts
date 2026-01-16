/**
 * OAuth2 Callback Route
 *
 * Handles the authorization callback from Thalamus
 */

import { NextRequest, NextResponse } from 'next/server'
import { thalamus } from '@/lib/thalamus'
import { cookies } from 'next/headers'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const code = searchParams.get('code')
  const state = searchParams.get('state')
  const error = searchParams.get('error')

  // Handle OAuth2 error
  if (error) {
    const errorDescription = searchParams.get('error_description') || error
    return NextResponse.redirect(
      new URL(`/?error=${encodeURIComponent(errorDescription)}`, request.url)
    )
  }

  // Validate required parameters
  if (!code || !state) {
    return NextResponse.redirect(
      new URL('/?error=missing_parameters', request.url)
    )
  }

  // Verify state (CSRF protection)
  const storedState = cookies().get('oauth_state')?.value
  if (!storedState || storedState !== state) {
    return NextResponse.redirect(
      new URL('/?error=invalid_state', request.url)
    )
  }

  // Clear state cookie
  cookies().delete('oauth_state')

  try {
    // Exchange authorization code for tokens
    const tokens = await thalamus.auth.exchangeCode(code)

    // Store tokens in httpOnly cookies
    const cookieOptions = {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax' as const,
      path: '/',
    }

    cookies().set('access_token', tokens.access_token, {
      ...cookieOptions,
      maxAge: tokens.expires_in,
    })

    if (tokens.refresh_token) {
      cookies().set('refresh_token', tokens.refresh_token, {
        ...cookieOptions,
        maxAge: 60 * 60 * 24 * 30, // 30 days
      })
    }

    // Redirect to dashboard
    return NextResponse.redirect(new URL('/dashboard', request.url))
  } catch (error: any) {
    console.error('Token exchange error:', error)
    return NextResponse.redirect(
      new URL(`/?error=${encodeURIComponent(error.message)}`, request.url)
    )
  }
}
