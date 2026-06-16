'use strict';

var react = require('react');

var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
  get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
}) : x)(function(x) {
  if (typeof require !== "undefined") return require.apply(this, arguments);
  throw Error('Dynamic require of "' + x + '" is not supported');
});

// src/client/auth/OAuth2.ts
var OAuth2 = class {
  constructor(config) {
    this.config = config;
  }
  config;
  /**
   * Generate OAuth2 authorization URL for user login
   *
   * @example
   * ```ts
   * const authUrl = thalamus.auth.getAuthorizationUrl({
   *   scope: ['openid', 'profile', 'email'],
   *   state: 'random-state-string'
   * })
   * // Redirect user to authUrl
   * ```
   */
  getAuthorizationUrl(options) {
    const {
      scope = this.config.defaultScopes || ["openid", "profile", "email"],
      state = this.generateState(),
      responseType = "code",
      codeChallenge,
      codeChallengeMethod
    } = options || {};
    const params = new URLSearchParams({
      response_type: responseType,
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      scope: Array.isArray(scope) ? scope.join(" ") : scope,
      state
    });
    if (codeChallenge) {
      params.set("code_challenge", codeChallenge);
      params.set("code_challenge_method", codeChallengeMethod || "S256");
    }
    return `${this.config.baseUrl}/oauth/authorize?${params.toString()}`;
  }
  /**
   * Exchange authorization code for access token
   *
   * @example
   * ```ts
   * const tokens = await thalamus.auth.exchangeCode('authorization_code_here')
   * console.log(tokens.access_token)
   * ```
   */
  async exchangeCode(codeOrOptions) {
    const code = typeof codeOrOptions === "string" ? codeOrOptions : codeOrOptions.code;
    const codeVerifier = typeof codeOrOptions === "string" ? void 0 : codeOrOptions.codeVerifier;
    const body = {
      grant_type: "authorization_code",
      code,
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      redirect_uri: this.config.redirectUri
    };
    if (codeVerifier) {
      body.code_verifier = codeVerifier;
    }
    return this.requestToken(body);
  }
  /**
   * Get access token using client credentials (M2M)
   *
   * @example
   * ```ts
   * const tokens = await thalamus.auth.getClientCredentialsToken({
   *   scope: ['api:read', 'api:write']
   * })
   * ```
   */
  async getClientCredentialsToken(options) {
    const { scope = this.config.defaultScopes || [] } = options || {};
    const body = {
      grant_type: "client_credentials",
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret
    };
    if (scope.length > 0) {
      body.scope = Array.isArray(scope) ? scope.join(" ") : scope;
    }
    return this.requestToken(body);
  }
  /**
   * Refresh access token using refresh token
   *
   * @example
   * ```ts
   * const newTokens = await thalamus.auth.refreshToken({
   *   refreshToken: 'rt_...'
   * })
   * ```
   */
  async refreshToken(options) {
    const body = {
      grant_type: "refresh_token",
      refresh_token: options.refreshToken,
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret
    };
    return this.requestToken(body);
  }
  /**
   * Revoke a token (access or refresh token)
   *
   * @example
   * ```ts
   * await thalamus.auth.revokeToken('at_...')
   * ```
   */
  async revokeToken(token, tokenTypeHint) {
    const body = {
      token
    };
    if (tokenTypeHint) {
      body.token_type_hint = tokenTypeHint;
    }
    const response = await fetch(`${this.config.baseUrl}/oauth/revoke`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    });
    if (!response.ok) {
      throw await this.handleError(response);
    }
  }
  /**
   * Generate random state for CSRF protection
   */
  generateState(length = 32) {
    const array = new Uint8Array(32);
    if (typeof crypto !== "undefined" && crypto.getRandomValues) {
      crypto.getRandomValues(array);
    } else {
      const cryptoModule = __require("crypto");
      cryptoModule.randomFillSync(array);
    }
    return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("");
  }
  /**
   * Make token request to /oauth/token
   */
  async requestToken(body) {
    const response = await fetch(`${this.config.baseUrl}/oauth/token`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    });
    if (!response.ok) {
      throw await this.handleError(response);
    }
    return response.json();
  }
  /**
   * Handle API errors
   */
  async handleError(response) {
    let errorData = {};
    try {
      errorData = await response.json();
    } catch {
    }
    const error = new Error(
      errorData.error_description || errorData.message || `HTTP ${response.status}`
    );
    error.statusCode = response.status;
    error.error = errorData.error;
    error.error_description = errorData.error_description;
    return error;
  }
};

// src/client/tokens/TokenManager.ts
var TokenManager = class {
  constructor(config) {
    this.config = config;
  }
  config;
  /**
   * Introspect a token to check if it's valid and get metadata
   *
   * @example
   * ```ts
   * const tokenInfo = await thalamus.tokens.introspect('at_...')
   * if (tokenInfo.active) {
   *   console.log(tokenInfo.user_id)
   *   console.log(tokenInfo.scope)
   * }
   * ```
   */
  async introspect(token) {
    const response = await fetch(`${this.config.baseUrl}/oauth/introspect`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ token })
    });
    if (!response.ok) {
      throw await this.handleError(response);
    }
    return response.json();
  }
  /**
   * Get user information from OpenID Connect userinfo endpoint
   *
   * @example
   * ```ts
   * const user = await thalamus.tokens.getUserInfo('at_...')
   * console.log(user.email)
   * console.log(user.name)
   * ```
   */
  async getUserInfo(accessToken) {
    const response = await fetch(`${this.config.baseUrl}/oauth/userinfo`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${accessToken}`
      }
    });
    if (!response.ok) {
      throw await this.handleError(response);
    }
    return response.json();
  }
  /**
   * Validate token and return true if active, false otherwise
   *
   * @example
   * ```ts
   * const isValid = await thalamus.tokens.validate('at_...')
   * if (isValid) {
   *   // Token is valid
   * }
   * ```
   */
  async validate(token) {
    try {
      const result = await this.introspect(token);
      return result.active === true;
    } catch {
      return false;
    }
  }
  /**
   * Handle API errors
   */
  async handleError(response) {
    let errorData = {};
    try {
      errorData = await response.json();
    } catch {
    }
    const error = new Error(
      errorData.error_description || errorData.message || `HTTP ${response.status}`
    );
    error.statusCode = response.status;
    error.error = errorData.error;
    error.error_description = errorData.error_description;
    return error;
  }
};

// src/client/admin/AdminAPI.ts
var AdminAPI = class {
  constructor(config) {
    this.config = config;
  }
  config;
  get baseUrl() {
    return this.config.baseUrl;
  }
  // ── Users ────────────────────────────────────────────────────────────────
  /** List all users */
  async listUsers() {
    const res = await this.request(`${this.baseUrl}/api/users`);
    const json = await res.json();
    return json.data ?? json;
  }
  /** List all agents (users with is_agent === true) */
  async listAgents() {
    const users = await this.listUsers();
    return users.filter((u) => u.is_agent === true);
  }
  /** Get a single user */
  async getUser(id) {
    const res = await this.request(`${this.baseUrl}/api/users/${id}`);
    const json = await res.json();
    return json.data ?? json;
  }
  /** Add a member to an organization */
  async addOrgMember(orgId, userId) {
    const res = await this.request(`${this.baseUrl}/api/organizations/${orgId}/members`, {
      method: "POST",
      body: JSON.stringify({ user_id: userId })
    });
    return res.json();
  }
  /** Update a user (only name and agent_config are writable) */
  async updateUser(id, data) {
    const res = await this.request(`${this.baseUrl}/api/users/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ user: data })
    });
    const json = await res.json();
    return json.data ?? json;
  }
  /** Create a user */
  async createUser(data) {
    const res = await this.request(`${this.baseUrl}/api/users`, {
      method: "POST",
      body: JSON.stringify({ user: data })
    });
    const json = await res.json();
    return json.data ?? json;
  }
  // ── Organizations ─────────────────────────────────────────────────────────
  /** Get an organization */
  async getOrganization(id) {
    const res = await this.request(`${this.baseUrl}/api/organizations/${id}`);
    const json = await res.json();
    return json.data ?? json;
  }
  /** List all organizations */
  async listOrganizations() {
    const res = await this.request(`${this.baseUrl}/api/organizations`);
    const json = await res.json();
    return json.data ?? json;
  }
  // ── Domain Roles ──────────────────────────────────────────────────────────
  /** List domain roles (optionally filtered) */
  async listDomainRoles(filters) {
    const params = new URLSearchParams();
    if (filters?.user_id) params.set("user_id", filters.user_id);
    if (filters?.organization_id) params.set("organization_id", filters.organization_id);
    if (filters?.domain) params.set("domain", filters.domain);
    const qs = params.toString();
    const url = `${this.baseUrl}/api/domains/roles${qs ? `?${qs}` : ""}`;
    const res = await this.request(url);
    const json = await res.json();
    return json.data ?? json;
  }
  /** Grant a domain role to a user */
  async grantDomainRole(params) {
    const res = await this.request(`${this.baseUrl}/api/domains/roles/grant`, {
      method: "POST",
      body: JSON.stringify(params)
    });
    return res.json();
  }
  /** Revoke a domain role from a user */
  async revokeDomainRole(params) {
    const res = await this.request(`${this.baseUrl}/api/domains/roles/revoke`, {
      method: "DELETE",
      body: JSON.stringify(params)
    });
    return res.json();
  }
  // ── Roles (RBAC) ──────────────────────────────────────────────────────────
  /** List all roles */
  async listRoles() {
    const res = await this.request(`${this.baseUrl}/api/roles`);
    const json = await res.json();
    return json.data ?? json;
  }
  /** Create a role */
  async createRole(params) {
    const res = await this.request(`${this.baseUrl}/api/roles`, {
      method: "POST",
      body: JSON.stringify(params)
    });
    const json = await res.json();
    return json.data ?? json;
  }
  /** Delete a role */
  async deleteRole(id) {
    await this.request(`${this.baseUrl}/api/roles/${id}`, { method: "DELETE" });
  }
  // ── User Roles ────────────────────────────────────────────────────────────
  /** Get user's effective scopes */
  async getEffectiveScopes(userId) {
    const res = await this.request(`${this.baseUrl}/api/users/${userId}/effective-scopes`);
    const json = await res.json();
    return json.data ?? json;
  }
  // ── Internal ──────────────────────────────────────────────────────────────
  getAccessToken() {
    if (typeof globalThis !== "undefined" && "localStorage" in globalThis) {
      const saved = globalThis.localStorage.getItem("auth");
      if (saved) {
        try {
          return JSON.parse(saved).accessToken;
        } catch {
          return null;
        }
      }
    }
    return null;
  }
  async request(url, options = {}) {
    const token = this.getAccessToken();
    const res = await fetch(url, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        ...token ? { Authorization: `Bearer ${token}` } : {},
        ...options.headers
      }
    });
    if (!res.ok) {
      throw await this.toError(res);
    }
    return res;
  }
  async toError(response) {
    let body = {};
    try {
      body = await response.json();
    } catch {
    }
    const error = new Error(
      body.error_description || body.error || `HTTP ${response.status}`
    );
    error.statusCode = response.status;
    error.error = body.error;
    error.error_description = body.error_description;
    return error;
  }
};

// src/client/ThalamusClient.ts
var ThalamusClient = class {
  /** OAuth2 authentication methods */
  auth;
  /** Token management and introspection */
  tokens;
  /** Admin API — users, orgs, roles, domain management */
  admin;
  config;
  /**
   * Create a new Thalamus client
   *
   * @param config - Client configuration
   */
  constructor(config) {
    if (!config.clientId) {
      throw new Error("clientId is required");
    }
    if (!config.redirectUri) {
      throw new Error("redirectUri is required");
    }
    if (!config.baseUrl) {
      throw new Error("baseUrl is required");
    }
    config.baseUrl = config.baseUrl.replace(/\/$/, "");
    this.config = config;
    this.auth = new OAuth2(config);
    this.tokens = new TokenManager(config);
    this.admin = new AdminAPI(config);
  }
  /**
   * Get the current configuration
   */
  getConfig() {
    return Object.freeze({ ...this.config });
  }
};

// src/hooks/useThalamus.ts
function useThalamus(options) {
  const storageKey = options.storageKey || "thalamus_auth";
  const clientRef = react.useRef(new ThalamusClient(options));
  const client = clientRef.current;
  const [token, setToken] = react.useState(null);
  const [user, setUser] = react.useState(null);
  const [isLoading, setIsLoading] = react.useState(true);
  const [error, setError] = react.useState(null);
  react.useEffect(() => {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved) {
        const { accessToken, refreshToken: rt } = JSON.parse(saved);
        setToken(accessToken);
        client.tokens.getUserInfo(accessToken).then((u) => setUser(u)).catch(() => {
        });
      }
    } catch {
    } finally {
      setIsLoading(false);
    }
  }, [storageKey]);
  react.useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get("code");
    const state = params.get("state");
    if (!code || !state) return;
    const savedState = sessionStorage.getItem(`${storageKey}_state`);
    if (state !== savedState) {
      setError("State mismatch \u2014 possible CSRF attack");
      return;
    }
    const verifier = sessionStorage.getItem(`${storageKey}_verifier`);
    if (!verifier) {
      setError("Missing code verifier");
      return;
    }
    client.auth.exchangeCode({ code, codeVerifier: verifier }).then((data) => {
      persistAuth(data);
      setToken(data.access_token);
      client.tokens.getUserInfo(data.access_token).then((u) => setUser(u)).catch(() => {
      });
      window.history.replaceState({}, "", window.location.pathname);
    }).catch((err) => setError(err.message));
  }, [storageKey]);
  const persistAuth = (data) => {
    localStorage.setItem(storageKey, JSON.stringify({ accessToken: data.access_token, refreshToken: data.refresh_token || null, expiresAt: Date.now() + data.expires_in * 1e3 }));
  };
  const login = react.useCallback(async (opts) => {
    setError(null);
    const verifier = client.auth.generateState();
    const challenge = await pkceChallenge(verifier);
    sessionStorage.setItem(`${storageKey}_verifier`, verifier);
    const url = client.auth.getAuthorizationUrl({ scope: opts?.scope, codeChallenge: challenge, codeChallengeMethod: "S256" });
    sessionStorage.setItem(`${storageKey}_state`, new URL(url).searchParams.get("state") || "");
    window.location.href = url;
  }, [storageKey]);
  const logout = react.useCallback(() => {
    localStorage.removeItem(storageKey);
    setToken(null);
    setUser(null);
  }, [storageKey]);
  const refreshToken = react.useCallback(async () => {
    try {
      const saved = localStorage.getItem(storageKey);
      if (!saved) return;
      const { refreshToken: rt } = JSON.parse(saved);
      if (!rt) return;
      const data = await client.auth.refreshToken({ refreshToken: rt });
      persistAuth(data);
      setToken(data.access_token);
    } catch {
    }
  }, [storageKey]);
  return {
    login,
    logout,
    token,
    user,
    isAuthenticated: !!token,
    isLoading,
    refreshToken,
    client,
    error
  };
}
async function pkceChallenge(verifier) {
  const encoder = new TextEncoder();
  const hash = await crypto.subtle.digest("SHA-256", encoder.encode(verifier));
  return btoa(String.fromCharCode(...new Uint8Array(hash))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function useAdmin(options) {
  const { baseUrl } = options;
  const clientRef = react.useRef(new ThalamusClient({ clientId: "admin", redirectUri: "", baseUrl }));
  const [users, setUsers] = react.useState([]);
  const [loading, setLoading] = react.useState(false);
  const [error, setError] = react.useState(null);
  const refresh = async () => {
    setLoading(true);
    setError(null);
    try {
      const u = await clientRef.current.admin.listUsers();
      setUsers(u);
    } catch (e) {
      setError(e.message);
    }
    setLoading(false);
  };
  react.useEffect(() => {
    if (options.autoFetch !== false) refresh();
  }, [baseUrl]);
  const agents = users.filter((u) => u.is_agent);
  const organizations = [];
  const roles = [];
  const createUser = async (data) => {
    try {
      const u = await clientRef.current.admin.createUser(data);
      setUsers((prev) => [...prev, u]);
      return u;
    } catch (e) {
      setError(e.message);
      return null;
    }
  };
  const listDomainRoles = async (filters) => {
    return clientRef.current.admin.listDomainRoles(filters);
  };
  return { users, agents, organizations, roles, loading, error, refresh, createUser, listDomainRoles };
}

exports.useAdmin = useAdmin;
exports.useThalamus = useThalamus;
//# sourceMappingURL=index.js.map
//# sourceMappingURL=index.js.map