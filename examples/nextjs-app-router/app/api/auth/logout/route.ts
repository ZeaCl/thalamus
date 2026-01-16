/**
 * Logout API Route
 *
 * Clears authentication cookies and redirects to home
 */

import { NextRequest, NextResponse } from 'next/server'
import { thalamus } from '@/lib/thalamus'
import { cookies } from 'next/headers'

export async function GET(request: NextRequest) {
  const accessToken = cookies().get('access_token')?.value

  // Revoke token with Thalamus
  if (accessToken) {
    try {
      await thalamus.auth.revokeToken(accessToken, 'access_token')
    } catch (error) {
      // Log but don't fail logout if revocation fails
      console.error('Token revocation error:', error)
    }
  }

  // Clear authentication cookies
  cookies().delete('access_token')
  cookies().delete('refresh_token')

  // Redirect to home page
  return NextResponse.redirect(new URL('/', request.url))
}
