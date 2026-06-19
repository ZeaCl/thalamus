import ThalamusClient from '@zea.cl/thalamus-js'

export const thalamus = new ThalamusClient({
  clientId: import.meta.env.VITE_THALAMUS_CLIENT_ID,
  redirectUri: import.meta.env.VITE_REDIRECT_URI,
  baseUrl: import.meta.env.VITE_THALAMUS_BASE_URL,
  defaultScopes: ['openid', 'profile', 'email', 'api:read']
})

export function generateRandomString(length) {
  const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~'
  let text = ''
  for (let i = 0; i < length; i++) {
    text += possible.charAt(Math.floor(Math.random() * possible.length))
  }
  return text
}

export async function sha256(plain) {
  const encoder = new TextEncoder()
  const data = encoder.encode(plain)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return base64urlencode(hash)
}

function base64urlencode(buffer) {
  const str = String.fromCharCode.apply(null, new Uint8Array(buffer))
  return btoa(str)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}
