# Tutorial 04: Aplicación Móvil - Integración con React Native y Flutter

Este tutorial muestra cómo integrar aplicaciones móviles (iOS/Android) con Thalamus usando **Authorization Code Flow + PKCE** (Proof Key for Code Exchange), el flujo recomendado y seguro para aplicaciones públicas.

**Basado en código real de Thalamus** (análisis directo del código, no especulación).

---

## 📋 Tabla de Contenidos

1. [¿Por Qué PKCE para Mobile?](#1-por-qué-pkce-para-mobile)
2. [Análisis del Flujo Authorization Code + PKCE](#2-análisis-del-flujo-authorization-code--pkce)
3. [Deep Linking para OAuth Callback](#3-deep-linking-para-oauth-callback)
4. [Almacenamiento Seguro de Tokens](#4-almacenamiento-seguro-de-tokens)
5. [Implementación en React Native](#5-implementación-en-react-native)
6. [Implementación en Flutter](#6-implementación-en-flutter)
7. [Refresh Token y Auto-Renovación](#7-refresh-token-y-auto-renovación)
8. [Logout y Revocación de Tokens](#8-logout-y-revocación-de-tokens)

---

## 1. ¿Por Qué PKCE para Mobile?

### El Problema con Client Secrets en Mobile

Las aplicaciones móviles son **clientes públicos** (public clients):
- El código de la app puede ser descompilado
- No hay forma segura de almacenar secrets
- Cualquiera puede extraer el `client_secret` del binario

### La Solución: PKCE (RFC 7636)

PKCE elimina la necesidad de `client_secret` usando **pruebas criptográficas dinámicas**:

1. ✅ **Sin client_secret** en el código de la app
2. ✅ **Protección contra ataques de intercepción** de código de autorización
3. ✅ **Requerido por RFC** para clientes públicos
4. ✅ **Soportado nativamente** por Thalamus

### Comparación de Flujos

| Característica | Client Secret | PKCE |
|----------------|---------------|------|
| **Client Type** | Confidential | Public |
| **Secret Storage** | Necesario | NO necesario |
| **Security** | Vulnerable si se extrae | Seguro incluso si se intercepta el código |
| **Mobile Apps** | ❌ NO recomendado | ✅ Recomendado |
| **Backend APIs** | ✅ Usar Client Credentials | ❌ NO usar para M2M |

---

## 2. Análisis del Flujo Authorization Code + PKCE

### Diagrama del Flujo Completo

```
┌──────────────┐                           ┌──────────────┐                           ┌──────────────┐
│  Mobile App  │                           │   Thalamus   │                           │  User Agent  │
│              │                           │   (Server)   │                           │  (Browser)   │
└──────┬───────┘                           └──────┬───────┘                           └──────┬───────┘
       │                                          │                                          │
       │ 1. Generar code_verifier y             │                                          │
       │    code_challenge                       │                                          │
       │                                          │                                          │
       │ 2. Abrir browser con URL autorización   │                                          │
       │    + code_challenge                      │                                          │
       ├────────────────────────────────────────────────────────────────────────────────────>│
       │                                          │                                          │
       │                                          │  3. GET /oauth/authorize                 │
       │                                          │     + code_challenge                     │
       │                                          │<─────────────────────────────────────────┤
       │                                          │                                          │
       │                                          │  4. Login y consent screen               │
       │                                          │────────────────────────────────────────>│
       │                                          │                                          │
       │                                          │  5. POST /oauth/authorize (approve)      │
       │                                          │<─────────────────────────────────────────┤
       │                                          │                                          │
       │                                          │  6. Genera authorization_code            │
       │                                          │     Guarda code_challenge                │
       │                                          │                                          │
       │                                          │  7. Redirect a myapp://callback?code=... │
       │                                          │────────────────────────────────────────>│
       │                                          │                                          │
       │  8. Deep link interceptado               │                                          │
       │<─────────────────────────────────────────────────────────────────────────────────────
       │                                          │
       │  9. POST /oauth/token                    │
       │     grant_type=authorization_code       │
       │     code=xxx                             │
       │     code_verifier=yyy                    │
       │─────────────────────────────────────────>│
       │                                          │
       │                                  10. Valida code_verifier
       │                                      SHA256(code_verifier) == code_challenge
       │                                          │
       │  11. Response: access_token +            │
       │      refresh_token                       │
       │<─────────────────────────────────────────┤
       │                                          │
       │  12. Guarda tokens en Keychain/Keystore  │
       │                                          │
```

### Paso 1: Generación de PKCE

**Code Verifier**: String aleatorio de 43-128 caracteres

```javascript
// React Native / JavaScript
function generateCodeVerifier() {
  const array = new Uint8Array(32) // 32 bytes = 43 caracteres en base64url
  crypto.getRandomValues(array)
  return base64URLEncode(array)
}

function base64URLEncode(buffer) {
  return btoa(String.fromCharCode.apply(null, buffer))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')
}

// Ejemplo: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
```

**Code Challenge**: SHA256 del code_verifier, encoded en base64url

```javascript
// React Native / JavaScript
async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return base64URLEncode(new Uint8Array(hash))
}

// Ejemplo: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
```

### Paso 2-7: Authorization Request

**URL de Autorización** (abrir en browser):

```
https://thalamus.example.com/oauth/authorize?
  response_type=code
  &client_id=mobile_app_client
  &redirect_uri=myapp://callback
  &scope=openid%20profile%20email%20api:read
  &state=random_state_string
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
```

**Parámetros PKCE**:
- `code_challenge`: SHA256 del code_verifier
- `code_challenge_method`: `S256` (SHA-256) o `plain` (no recomendado)

### Análisis del Código: `authorization_controller.ex`

```elixir
defp extract_and_validate_pkce_params(params) do
  code_challenge = params["code_challenge"]
  code_challenge_method = params["code_challenge_method"] || "S256"

  if code_challenge do
    case code_challenge_method do
      method when method in ["S256", "plain"] ->
        {:ok, %{code_challenge: code_challenge, code_challenge_method: method}}

      _ ->
        {:error, "invalid_request", "Invalid code_challenge_method"}
    end
  else
    # PKCE opcional (pero recomendado)
    {:ok, %{code_challenge: nil, code_challenge_method: nil}}
  end
end
```

**Importante**: Thalamus **guarda** el `code_challenge` junto con el authorization_code para validarlo después.

### Paso 8: Deep Link Callback

Después de login y consent, Thalamus redirige a:

```
myapp://callback?code=ac_xxx...&state=random_state_string
```

La app móvil intercepta esta URL via deep linking.

### Paso 9-11: Token Exchange con PKCE

**Código Real**: `lib/thalamus/application/use_cases/generate_tokens.ex`

```elixir
defp verify_pkce(nil, %{pkce_challenge: nil}), do: :ok

defp verify_pkce(verifier, %{pkce_challenge: challenge}) when is_binary(verifier) do
  # Calcular hash del verifier
  computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

  if computed == challenge do
    :ok
  else
    {:error, :invalid_pkce_verifier}
  end
end

defp verify_pkce(nil, %{pkce_challenge: _challenge}), do: {:error, :pkce_verifier_required}
```

**Request**:

```http
POST /oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "ac_xxx...",
  "client_id": "mobile_app_client",
  "redirect_uri": "myapp://callback",
  "code_verifier": "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
}
```

**Nota**: NO enviar `client_secret` para clientes públicos con PKCE.

**Response**:

```json
{
  "access_token": "at_s3cur3T0k3n...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "rt_r3fr3shT0k3n...",
  "scope": "openid profile email api:read"
}
```

### Errores PKCE Comunes

| Error | Causa | Solución |
|-------|-------|----------|
| `invalid_pkce_verifier` | SHA256(code_verifier) ≠ code_challenge guardado | Verificar que el verifier sea el mismo que generaste |
| `pkce_verifier_required` | Se usó code_challenge pero no se envió code_verifier | Enviar code_verifier en token request |
| `invalid_grant` | Código expirado (10 min) | Reiniciar flujo de autorización |

---

## 3. Deep Linking para OAuth Callback

### 3.1. Configuración de URL Scheme

#### iOS (Info.plist)

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.example.myapp</string>
  </dict>
</array>
```

#### Android (AndroidManifest.xml)

```xml
<activity
  android:name=".MainActivity"
  android:launchMode="singleTask">

  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />

    <data
      android:scheme="myapp"
      android:host="callback" />
  </intent-filter>
</activity>
```

### 3.2. Universal Links / App Links (Recomendado)

Usar HTTPS en lugar de custom schemes:

**iOS Universal Links**: `https://myapp.com/auth/callback`
**Android App Links**: `https://myapp.com/auth/callback`

Ventajas:
- ✅ Más seguro (dominio verificado)
- ✅ Fallback a navegador si app no instalada
- ✅ Mejor UX (no pregunta qué app abrir)

---

## 4. Almacenamiento Seguro de Tokens

### ⚠️ NUNCA Almacenar en:

- ❌ `AsyncStorage` / `localStorage` (accesible por otras apps en Android rooted)
- ❌ `SharedPreferences` sin encriptación
- ❌ Archivos de texto plano

### ✅ Usar Almacenamiento Seguro:

#### iOS: Keychain

```swift
// Swift
import Security

func saveToken(token: String, key: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: token.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]

    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}
```

#### Android: EncryptedSharedPreferences / Keystore

```kotlin
// Kotlin
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)

val sharedPreferences = EncryptedSharedPreferences.create(
    "secure_prefs",
    masterKeyAlias,
    context,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)

sharedPreferences.edit().putString("access_token", token).apply()
```

---

## 5. Implementación en React Native

### 5.1. Instalación de Dependencias

```bash
npm install react-native-app-auth react-native-keychain
```

### 5.2. Configuración de OAuth

```javascript
// src/config/oauth.js
import { authorize, refresh, revoke } from 'react-native-app-auth'

const config = {
  issuer: 'https://thalamus.example.com',
  clientId: 'mobile_app_client',
  redirectUrl: 'myapp://callback',
  scopes: ['openid', 'profile', 'email', 'api:read'],

  // Endpoints (opcional si issuer soporta discovery)
  serviceConfiguration: {
    authorizationEndpoint: 'https://thalamus.example.com/oauth/authorize',
    tokenEndpoint: 'https://thalamus.example.com/oauth/token',
    revocationEndpoint: 'https://thalamus.example.com/oauth/revoke',
  },

  // PKCE habilitado automáticamente
  usePKCE: true,

  // Parámetros adicionales
  additionalParameters: {
    prompt: 'login', // Forzar login cada vez
  },
}

export default config
```

### 5.3. Hook de Autenticación

```javascript
// src/hooks/useAuth.js
import { useState, useEffect } from 'react'
import { authorize, refresh as refreshAuth, revoke as revokeAuth } from 'react-native-app-auth'
import * as Keychain from 'react-native-keychain'
import oauthConfig from '../config/oauth'

export function useAuth() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [accessToken, setAccessToken] = useState(null)
  const [refreshToken, setRefreshToken] = useState(null)
  const [loading, setLoading] = useState(true)

  // Cargar tokens al iniciar
  useEffect(() => {
    loadTokens()
  }, [])

  async function loadTokens() {
    try {
      const credentials = await Keychain.getGenericPassword()
      if (credentials) {
        const tokens = JSON.parse(credentials.password)
        setAccessToken(tokens.accessToken)
        setRefreshToken(tokens.refreshToken)
        setIsAuthenticated(true)
      }
    } catch (error) {
      console.error('Failed to load tokens:', error)
    } finally {
      setLoading(false)
    }
  }

  async function saveTokens(tokens) {
    try {
      await Keychain.setGenericPassword(
        'auth_tokens',
        JSON.stringify({
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresAt: Date.now() + tokens.expiresIn * 1000,
        })
      )
      setAccessToken(tokens.accessToken)
      setRefreshToken(tokens.refreshToken)
      setIsAuthenticated(true)
    } catch (error) {
      console.error('Failed to save tokens:', error)
    }
  }

  async function login() {
    try {
      setLoading(true)
      const result = await authorize(oauthConfig)

      await saveTokens({
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresIn: result.accessTokenExpirationDate
          ? (new Date(result.accessTokenExpirationDate).getTime() - Date.now()) / 1000
          : 3600,
      })

      return result
    } catch (error) {
      console.error('Login failed:', error)
      throw error
    } finally {
      setLoading(false)
    }
  }

  async function refreshAccessToken() {
    try {
      if (!refreshToken) {
        throw new Error('No refresh token available')
      }

      const result = await refreshAuth(oauthConfig, {
        refreshToken: refreshToken,
      })

      await saveTokens({
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresIn: result.accessTokenExpirationDate
          ? (new Date(result.accessTokenExpirationDate).getTime() - Date.now()) / 1000
          : 3600,
      })

      return result
    } catch (error) {
      console.error('Token refresh failed:', error)
      // Si refresh falla, cerrar sesión
      await logout()
      throw error
    }
  }

  async function logout() {
    try {
      if (accessToken) {
        // Revocar token en servidor
        await revokeAuth(oauthConfig, {
          tokenToRevoke: accessToken,
          includeBasicAuth: false,
        })
      }
    } catch (error) {
      console.error('Token revocation failed:', error)
    } finally {
      // Limpiar tokens locales
      await Keychain.resetGenericPassword()
      setAccessToken(null)
      setRefreshToken(null)
      setIsAuthenticated(false)
    }
  }

  return {
    isAuthenticated,
    accessToken,
    refreshToken,
    loading,
    login,
    logout,
    refreshAccessToken,
  }
}
```

### 5.4. Axios Interceptor con Auto-Refresh

```javascript
// src/api/client.js
import axios from 'axios'
import { useAuth } from '../hooks/useAuth'

const apiClient = axios.create({
  baseURL: 'https://api.example.com',
})

export function setupInterceptors(auth) {
  // Request interceptor: agregar token
  apiClient.interceptors.request.use(
    (config) => {
      if (auth.accessToken) {
        config.headers.Authorization = `Bearer ${auth.accessToken}`
      }
      return config
    },
    (error) => Promise.reject(error)
  )

  // Response interceptor: auto-refresh en 401
  apiClient.interceptors.response.use(
    (response) => response,
    async (error) => {
      const originalRequest = error.config

      if (error.response?.status === 401 && !originalRequest._retry) {
        originalRequest._retry = true

        try {
          // Intentar refresh token
          await auth.refreshAccessToken()

          // Reintentar request original con nuevo token
          originalRequest.headers.Authorization = `Bearer ${auth.accessToken}`
          return apiClient(originalRequest)
        } catch (refreshError) {
          // Refresh falló - redirigir a login
          return Promise.reject(refreshError)
        }
      }

      return Promise.reject(error)
    }
  )
}

export default apiClient
```

### 5.5. Pantalla de Login

```javascript
// src/screens/LoginScreen.js
import React from 'react'
import { View, Button, Text, ActivityIndicator } from 'react-native'
import { useAuth } from '../hooks/useAuth'

export default function LoginScreen() {
  const { login, loading } = useAuth()

  async function handleLogin() {
    try {
      await login()
      // Navegación manejada automáticamente por auth state
    } catch (error) {
      console.error('Login error:', error)
      alert('Login failed. Please try again.')
    }
  }

  if (loading) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator size="large" />
      </View>
    )
  }

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Text style={{ fontSize: 24, marginBottom: 20 }}>Welcome to MyApp</Text>
      <Button title="Login with Thalamus" onPress={handleLogin} />
    </View>
  )
}
```

---

## 6. Implementación en Flutter

### 6.1. Instalación de Dependencias

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_appauth: ^6.0.0
  flutter_secure_storage: ^9.0.0
  http: ^1.1.0
```

### 6.2. Configuración de OAuth

```dart
// lib/config/oauth_config.dart
import 'package:flutter_appauth/flutter_appauth.dart';

class OAuthConfig {
  static const String clientId = 'mobile_app_client';
  static const String redirectUrl = 'com.example.myapp://callback';
  static const String issuer = 'https://thalamus.example.com';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'api:read',
  ];

  static final FlutterAppAuth appAuth = FlutterAppAuth();

  static final AuthorizationServiceConfiguration serviceConfig =
    AuthorizationServiceConfiguration(
      authorizationEndpoint: '$issuer/oauth/authorize',
      tokenEndpoint: '$issuer/oauth/token',
      endSessionEndpoint: '$issuer/oauth/revoke',
    );
}
```

### 6.3. Servicio de Autenticación

```dart
// lib/services/auth_service.dart
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/oauth_config.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _appAuth = OAuthConfig.appAuth;

  String? _accessToken;
  String? _refreshToken;

  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;

  // Cargar tokens del storage
  Future<void> loadTokens() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
  }

  // Login con Authorization Code + PKCE
  Future<void> login() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          OAuthConfig.clientId,
          OAuthConfig.redirectUrl,
          serviceConfiguration: OAuthConfig.serviceConfig,
          scopes: OAuthConfig.scopes,
          // PKCE habilitado automáticamente
        ),
      );

      if (result != null) {
        await _saveTokens(
          result.accessToken!,
          result.refreshToken,
        );
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Refresh token
  Future<void> refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    try {
      final result = await _appAuth.token(
        TokenRequest(
          OAuthConfig.clientId,
          OAuthConfig.redirectUrl,
          serviceConfiguration: OAuthConfig.serviceConfig,
          refreshToken: _refreshToken,
        ),
      );

      if (result != null) {
        await _saveTokens(
          result.accessToken!,
          result.refreshToken ?? _refreshToken,
        );
      }
    } catch (e) {
      print('Token refresh error: $e');
      await logout();
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Revocar token en servidor
      if (_accessToken != null) {
        // Llamar a endpoint de revocación
        // await http.post(...)
      }
    } finally {
      // Limpiar tokens locales
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      _accessToken = null;
      _refreshToken = null;
    }
  }

  // Guardar tokens en secure storage
  Future<void> _saveTokens(String accessToken, String? refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }
}
```

### 6.4. HTTP Client con Auto-Refresh

```dart
// lib/services/api_client.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class ApiClient {
  final AuthService _authService;
  final String baseUrl;

  ApiClient(this._authService, this.baseUrl);

  Future<http.Response> get(String path) async {
    return _request('GET', path);
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    return _request('POST', path, body: body);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (_authService.accessToken != null)
        'Authorization': 'Bearer ${_authService.accessToken}',
    };

    http.Response response;

    if (method == 'GET') {
      response = await http.get(url, headers: headers);
    } else if (method == 'POST') {
      response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    // Auto-refresh en 401
    if (response.statusCode == 401 && retry) {
      await _authService.refreshAccessToken();
      return _request(method, path, body: body, retry: false);
    }

    return response;
  }
}
```

---

## 7. Refresh Token y Auto-Renovación

### Estrategia de Renovación

1. **Verificar expiración** antes de cada request
2. **Auto-refresh** en 401 Unauthorized
3. **Renovación proactiva** 5 minutos antes de expirar

### Implementación Proactiva (React Native)

```javascript
// src/hooks/useAutoRefresh.js
import { useEffect, useRef } from 'react'

export function useAutoRefresh(auth) {
  const refreshTimerRef = useRef(null)

  useEffect(() => {
    if (auth.isAuthenticated) {
      scheduleTokenRefresh()
    }

    return () => {
      if (refreshTimerRef.current) {
        clearTimeout(refreshTimerRef.current)
      }
    }
  }, [auth.isAuthenticated])

  async function scheduleTokenRefresh() {
    try {
      // Obtener tiempo de expiración
      const credentials = await Keychain.getGenericPassword()
      if (!credentials) return

      const tokens = JSON.parse(credentials.password)
      const expiresAt = tokens.expiresAt
      const now = Date.now()

      // Refrescar 5 minutos antes de expirar
      const refreshAt = expiresAt - 5 * 60 * 1000
      const delay = refreshAt - now

      if (delay > 0) {
        refreshTimerRef.current = setTimeout(async () => {
          try {
            await auth.refreshAccessToken()
            // Programar siguiente refresh
            scheduleTokenRefresh()
          } catch (error) {
            console.error('Auto-refresh failed:', error)
          }
        }, delay)
      } else {
        // Token ya expiró, refrescar inmediatamente
        await auth.refreshAccessToken()
        scheduleTokenRefresh()
      }
    } catch (error) {
      console.error('Failed to schedule token refresh:', error)
    }
  }
}
```

---

## 8. Logout y Revocación de Tokens

### Logout Completo

1. **Revocar token** en Thalamus
2. **Limpiar storage** local
3. **Navegar** a pantalla de login

### Implementación

```javascript
// React Native
async function logout() {
  try {
    // 1. Revocar access token
    if (accessToken) {
      await fetch('https://thalamus.example.com/oauth/revoke', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token: accessToken,
          token_type_hint: 'access_token',
        }),
      })
    }

    // 2. Revocar refresh token
    if (refreshToken) {
      await fetch('https://thalamus.example.com/oauth/revoke', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token: refreshToken,
          token_type_hint: 'refresh_token',
        }),
      })
    }
  } catch (error) {
    console.error('Token revocation failed:', error)
    // Continuar con logout local incluso si revocación falla
  } finally {
    // 3. Limpiar storage local
    await Keychain.resetGenericPassword()
    setAccessToken(null)
    setRefreshToken(null)
    setIsAuthenticated(false)
  }
}
```

---

## 📝 Resumen

### ✅ Checklist de Implementación

- [ ] Configurar OAuth2 client en Thalamus como **public client**
- [ ] Configurar deep linking (URL scheme o Universal Links)
- [ ] Implementar generación de PKCE (code_verifier y code_challenge)
- [ ] Abrir browser con URL de autorización + code_challenge
- [ ] Interceptar deep link callback con authorization_code
- [ ] Intercambiar code por tokens usando code_verifier
- [ ] Almacenar tokens en Keychain (iOS) o Keystore (Android)
- [ ] Implementar auto-refresh de tokens
- [ ] Implementar logout con revocación de tokens
- [ ] Añadir manejo de errores (token expirado, network, etc.)

### 🔑 Puntos Clave

1. **PKCE es obligatorio** para apps móviles (clientes públicos)
2. **NO usar client_secret** en mobile - usar PKCE en su lugar
3. **Almacenar tokens de forma segura** - Keychain/Keystore, NO AsyncStorage
4. **Deep linking** es necesario para recibir authorization code
5. **Auto-refresh** de tokens para mejor UX
6. **Revocar tokens** al hacer logout
7. **Universal Links/App Links** son mejores que custom URL schemes

### 📚 Próximos Pasos

- **Tutorial 05**: Authorization Code Flow detallado
- **Tutorial 07**: Token Refresh en profundidad
- **Tutorial 09**: MFA Integration para mobile

---

**Última actualización**: 2026-01-23 (basado en código real de Thalamus)
