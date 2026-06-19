# Tutorial: Frontend Web (React/Next.js)

**Basado en el código real de Thalamus** | Última actualización: 2026-01-23

Guía completa para integrar Thalamus en aplicaciones frontend web usando Authorization Code Flow + PKCE.

---

## 📋 Tabla de Contenidos

1. [Overview](#1-overview)
2. [Authorization Code + PKCE](#2-authorization-code--pkce)
3. [Implementación React SPA](#3-implementación-react-spa)
4. [Implementación Next.js](#4-implementación-nextjs)
5. [Manejo de Tokens](#5-manejo-de-tokens)
6. [Rutas Protegidas](#6-rutas-protegidas)
7. [Refresh Tokens](#7-refresh-tokens)
8. [Mejores Prácticas](#8-mejores-prácticas)

---

## 1. Overview

### 1.1 ¿Por Qué PKCE?

**Del código de Thalamus:**

```elixir
# lib/thalamus_web/controllers/oauth2/authorization_controller.ex
# PKCE es OBLIGATORIO para clientes públicos (SPAs)

def new(conn, params) do
  # Extrae y valida parámetros PKCE
  {:ok, pkce_params} <- extract_and_validate_pkce_params(params)
  # code_challenge y code_challenge_method
end

def create(conn, params) do
  # Al generar el código de autorización, guarda el code_challenge
  # para validarlo después en /oauth/token
end
```

**¿Por qué?**
- SPAs no pueden guardar client_secret de forma segura
- PKCE previene intercepción del authorization code
- Requerido por RFC 7636 para clientes públicos

### 1.2 Flujo Visual

```
┌─────────┐                ┌─────────┐              ┌──────────┐
│ Browser │                │ Tu App  │              │ Thalamus │
└────┬────┘                └────┬────┘              └────┬─────┘
     │                          │                        │
     │ 1. Click "Login"         │                        │
     ├─────────────────────────>│                        │
     │                          │                        │
     │                  2. Generate PKCE                 │
     │                     code_verifier                 │
     │                     code_challenge                │
     │                          │                        │
     │  3. Redirect /oauth/authorize?                    │
     │     code_challenge=xxx&...                        │
     ├──────────────────────────┼───────────────────────>│
     │                          │                        │
     │          4. Login Form   │                        │
     │  <───────────────────────┼────────────────────────┤
     │                          │                        │
     │  5. POST credentials     │                        │
     ├──────────────────────────┼───────────────────────>│
     │                          │                        │
     │  6. Redirect /callback?code=abc&state=xyz         │
     │  <───────────────────────┼────────────────────────┤
     │                          │                        │
     │ 7. GET /callback         │                        │
     ├─────────────────────────>│                        │
     │                          │                        │
     │                  8. POST /oauth/token             │
     │                     code=abc                      │
     │                     code_verifier=yyy             │
     │                          ├───────────────────────>│
     │                          │                        │
     │                          │  9. Validate PKCE      │
     │                          │     SHA256(verifier)   │
     │                          │     == challenge?      │
     │                          │                        │
     │                          │  10. {access_token}    │
     │                          │  <─────────────────────┤
     │                          │                        │
     │  11. Redirect /dashboard │                        │
     │     (with token)         │                        │
     │  <───────────────────────┤                        │
```

---

## 2. Authorization Code + PKCE

### 2.1 Generar PKCE Challenge

```javascript
// utils/pkce.js

/**
 * Genera code_verifier aleatorio (128 caracteres)
 */
export function generateCodeVerifier() {
  const array = new Uint8Array(96); // 96 bytes = 128 chars en base64url
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}

/**
 * Genera code_challenge desde code_verifier
 * Usa SHA-256 como requiere Thalamus
 */
export async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return base64URLEncode(new Uint8Array(hash));
}

/**
 * Codifica en base64url (sin padding)
 */
function base64URLEncode(buffer) {
  const base64 = btoa(String.fromCharCode.apply(null, buffer));
  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

/**
 * Genera state para CSRF protection
 */
export function generateState() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}
```

### 2.2 Iniciar Authorization Flow

```javascript
// services/auth.js

const THALAMUS_URL = process.env.REACT_APP_THALAMUS_URL || 'http://localhost:4000';
const CLIENT_ID = process.env.REACT_APP_CLIENT_ID;
const REDIRECT_URI = process.env.REACT_APP_REDIRECT_URI || 'http://localhost:3000/auth/callback';

export async function initiateLogin() {
  // 1. Generar PKCE
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  const state = generateState();

  // 2. Guardar en sessionStorage (temporal)
  sessionStorage.setItem('pkce_code_verifier', codeVerifier);
  sessionStorage.setItem('oauth_state', state);

  // 3. Construir URL de autorización
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    scope: 'openid profile email',
    state: state,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256'  // Thalamus requiere S256
  });

  // 4. Redirigir a Thalamus
  window.location.href = `${THALAMUS_URL}/oauth/authorize?${params}`;
}
```

---

## 3. Implementación React SPA

### 3.1 Estructura del Proyecto

```
src/
├── components/
│   ├── LoginButton.jsx
│   ├── LogoutButton.jsx
│   └── ProtectedRoute.jsx
├── pages/
│   ├── Home.jsx
│   ├── Callback.jsx
│   ├── Dashboard.jsx
│   └── Profile.jsx
├── services/
│   ├── auth.js
│   └── api.js
├── utils/
│   └── pkce.js
├── hooks/
│   └── useAuth.js
└── App.jsx
```

### 3.2 Hook de Autenticación

```javascript
// hooks/useAuth.js
import { createContext, useContext, useState, useEffect } from 'react';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [accessToken, setAccessToken] = useState(null);

  useEffect(() => {
    // Cargar token del localStorage al iniciar
    const token = localStorage.getItem('access_token');
    if (token) {
      setAccessToken(token);
      loadUserInfo(token);
    } else {
      setLoading(false);
    }
  }, []);

  async function loadUserInfo(token) {
    try {
      const response = await fetch(`${THALAMUS_URL}/oauth/userinfo`, {
        headers: { Authorization: `Bearer ${token}` }
      });

      if (response.ok) {
        const userData = await response.json();
        setUser(userData);
      } else {
        // Token inválido
        logout();
      }
    } catch (error) {
      console.error('Failed to load user info:', error);
      logout();
    } finally {
      setLoading(false);
    }
  }

  function login(token, refreshToken) {
    localStorage.setItem('access_token', token);
    if (refreshToken) {
      localStorage.setItem('refresh_token', refreshToken);
    }
    setAccessToken(token);
    loadUserInfo(token);
  }

  function logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    setAccessToken(null);
    setUser(null);
  }

  const value = {
    user,
    accessToken,
    loading,
    isAuthenticated: !!user,
    login,
    logout
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
```

### 3.3 Componente de Login

```javascript
// components/LoginButton.jsx
import { initiateLogin } from '../services/auth';

export default function LoginButton() {
  return (
    <button
      onClick={initiateLogin}
      className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
    >
      Sign in with Thalamus
    </button>
  );
}
```

### 3.4 Callback Handler

```javascript
// pages/Callback.jsx
import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

export default function Callback() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { login } = useAuth();
  const [error, setError] = useState(null);

  useEffect(() => {
    async function handleCallback() {
      try {
        // 1. Extraer parámetros
        const code = searchParams.get('code');
        const state = searchParams.get('state');
        const error = searchParams.get('error');

        // 2. Verificar errores
        if (error) {
          throw new Error(searchParams.get('error_description') || error);
        }

        if (!code) {
          throw new Error('No authorization code received');
        }

        // 3. Validar state (CSRF protection)
        const savedState = sessionStorage.getItem('oauth_state');
        if (state !== savedState) {
          throw new Error('Invalid state - possible CSRF attack');
        }

        // 4. Obtener code_verifier
        const codeVerifier = sessionStorage.getItem('pkce_code_verifier');
        if (!codeVerifier) {
          throw new Error('No code verifier found');
        }

        // 5. Intercambiar código por tokens
        const response = await fetch(`${THALAMUS_URL}/oauth/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            grant_type: 'authorization_code',
            code,
            client_id: CLIENT_ID,
            redirect_uri: REDIRECT_URI,
            code_verifier: codeVerifier
          })
        });

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error_description || 'Token exchange failed');
        }

        const tokens = await response.json();

        // 6. Guardar tokens
        login(tokens.access_token, tokens.refresh_token);

        // 7. Limpiar storage temporal
        sessionStorage.removeItem('pkce_code_verifier');
        sessionStorage.removeItem('oauth_state');

        // 8. Redirigir
        navigate('/dashboard');

      } catch (err) {
        console.error('Callback error:', err);
        setError(err.message);
      }
    }

    handleCallback();
  }, [searchParams, navigate, login]);

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-red-600 mb-4">
            Authentication Failed
          </h1>
          <p className="text-gray-600 mb-4">{error}</p>
          <button
            onClick={() => navigate('/')}
            className="px-4 py-2 bg-blue-600 text-white rounded"
          >
            Return to Home
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
        <p className="text-gray-600">Processing authentication...</p>
      </div>
    </div>
  );
}
```

### 3.5 Rutas Protegidas

```javascript
// components/ProtectedRoute.jsx
import { Navigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

export default function ProtectedRoute({ children }) {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  return children;
}
```

### 3.6 App Component

```javascript
// App.jsx
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './hooks/useAuth';
import ProtectedRoute from './components/ProtectedRoute';
import Home from './pages/Home';
import Callback from './pages/Callback';
import Dashboard from './pages/Dashboard';
import Profile from './pages/Profile';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/auth/callback" element={<Callback />} />
          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/profile"
            element={
              <ProtectedRoute>
                <Profile />
              </ProtectedRoute>
            }
          />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
```

---

## 4. Implementación Next.js

### 4.1 Usando NextAuth.js

```javascript
// pages/api/auth/[...nextauth].js
import NextAuth from 'next-auth';

export default NextAuth({
  providers: [
    {
      id: 'thalamus',
      name: 'Thalamus',
      type: 'oauth',
      wellKnown: `${process.env.THALAMUS_URL}/.well-known/openid-configuration`,
      authorization: {
        params: {
          scope: 'openid profile email',
          // NextAuth.js maneja PKCE automáticamente
        }
      },
      clientId: process.env.THALAMUS_CLIENT_ID,
      clientSecret: process.env.THALAMUS_CLIENT_SECRET, // Opcional para PKCE
      idToken: true,
      checks: ['state', 'pkce'],
      profile(profile) {
        return {
          id: profile.sub,
          name: profile.name,
          email: profile.email,
          image: profile.picture
        };
      }
    }
  ],
  callbacks: {
    async jwt({ token, account }) {
      if (account) {
        token.accessToken = account.access_token;
        token.refreshToken = account.refresh_token;
      }
      return token;
    },
    async session({ session, token }) {
      session.accessToken = token.accessToken;
      session.refreshToken = token.refreshToken;
      return session;
    }
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error'
  }
});
```

### 4.2 Protected Page

```javascript
// pages/dashboard.js
import { getSession } from 'next-auth/react';
import { useSession, signIn } from 'next-auth/react';

export default function Dashboard() {
  const { data: session, status } = useSession({
    required: true,
    onUnauthenticated() {
      signIn('thalamus');
    }
  });

  if (status === 'loading') {
    return <div>Loading...</div>;
  }

  return (
    <div>
      <h1>Dashboard</h1>
      <p>Welcome, {session.user.name}!</p>
      <p>Email: {session.user.email}</p>
    </div>
  );
}

export async function getServerSideProps(context) {
  const session = await getSession(context);

  if (!session) {
    return {
      redirect: {
        destination: '/api/auth/signin',
        permanent: false
      }
    };
  }

  return {
    props: { session }
  };
}
```

---

## 5. Manejo de Tokens

### 5.1 Interceptor de API

```javascript
// services/api.js
import axios from 'axios';

const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL
});

// Interceptor de request: añadir token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Interceptor de response: manejar 401
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // Si es 401 y no hemos intentado refresh
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        // Intentar refresh
        const newToken = await refreshAccessToken();
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return api(originalRequest);
      } catch (refreshError) {
        // Refresh falló - logout
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        window.location.href = '/';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default api;
```

---

## 6. Rutas Protegidas

### 6.1 Higher-Order Component

```javascript
// components/withAuth.jsx
import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../hooks/useAuth';

export function withAuth(Component) {
  return function ProtectedRoute(props) {
    const { isAuthenticated, loading } = useAuth();
    const router = useRouter();

    useEffect(() => {
      if (!loading && !isAuthenticated) {
        router.push('/');
      }
    }, [isAuthenticated, loading, router]);

    if (loading) {
      return <div>Loading...</div>;
    }

    if (!isAuthenticated) {
      return null;
    }

    return <Component {...props} />;
  };
}

// Uso:
export default withAuth(DashboardPage);
```

---

## 7. Refresh Tokens

### 7.1 Implementación

```javascript
// services/auth.js

export async function refreshAccessToken() {
  const refreshToken = localStorage.getItem('refresh_token');

  if (!refreshToken) {
    throw new Error('No refresh token available');
  }

  const response = await fetch(`${THALAMUS_URL}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: CLIENT_ID
    })
  });

  if (!response.ok) {
    throw new Error('Token refresh failed');
  }

  const tokens = await response.json();

  // Guardar nuevos tokens
  localStorage.setItem('access_token', tokens.access_token);
  if (tokens.refresh_token) {
    // Token rotation: nuevo refresh_token
    localStorage.setItem('refresh_token', tokens.refresh_token);
  }

  return tokens.access_token;
}
```

### 7.2 Auto-Refresh antes de Expirar

```javascript
// hooks/useTokenRefresh.js
import { useEffect } from 'react';
import { useAuth } from './useAuth';
import { refreshAccessToken } from '../services/auth';

export function useTokenRefresh() {
  const { accessToken, login } = useAuth();

  useEffect(() => {
    if (!accessToken) return;

    // Decodificar token para obtener exp
    const payload = JSON.parse(atob(accessToken.split('.')[1]));
    const expiresAt = payload.exp * 1000;
    const now = Date.now();

    // Refresh 5 minutos antes de expirar
    const refreshTime = expiresAt - now - (5 * 60 * 1000);

    if (refreshTime > 0) {
      const timer = setTimeout(async () => {
        try {
          const newToken = await refreshAccessToken();
          login(newToken, localStorage.getItem('refresh_token'));
        } catch (error) {
          console.error('Auto-refresh failed:', error);
        }
      }, refreshTime);

      return () => clearTimeout(timer);
    }
  }, [accessToken, login]);
}
```

---

## 8. Mejores Prácticas

### 8.1 Seguridad

```javascript
// ✅ CORRECTO
// 1. Usar httpOnly cookies en producción (más seguro que localStorage)
// 2. Validar state parameter siempre
// 3. HTTPS en producción
// 4. Implementar CSP headers

// ❌ INCORRECTO
// 1. No guardar tokens en localStorage en producción
// 2. No enviar client_secret desde el frontend
// 3. No deshabilitar PKCE
```

### 8.2 Variables de Entorno

```env
# .env
REACT_APP_THALAMUS_URL=http://localhost:4000
REACT_APP_CLIENT_ID=your_client_id
REACT_APP_REDIRECT_URI=http://localhost:3000/auth/callback
REACT_APP_API_URL=http://localhost:3001/api
```

### 8.3 Error Handling

```javascript
// Manejar errores específicos de OAuth2
function handleOAuthError(error, errorDescription) {
  switch (error) {
    case 'access_denied':
      return 'Usuario denegó el acceso';
    case 'invalid_client':
      return 'Configuración de cliente inválida';
    case 'invalid_grant':
      return 'Código de autorización inválido o expirado';
    default:
      return errorDescription || 'Error de autenticación';
  }
}
```

---

## 📚 Próximos Pasos

- **Backend API**: [Tutorial 03](./03-backend-api.md)
- **Token Refresh**: [Tutorial 07](./07-token-refresh.md)
- **Ejemplos Completos**: `/examples/react-spa/`

## 🔗 Referencias del Código

- `lib/thalamus_web/controllers/oauth2/authorization_controller.ex`
- `lib/thalamus_web/controllers/oauth2/token_controller.ex`
- `/examples/react-spa/` - Ejemplo funcional completo

**Última revisión del código:** 2026-01-23
