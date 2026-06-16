import { useRef, useState, useEffect, useCallback } from 'react';
import { jsx, jsxs, Fragment } from 'react/jsx-runtime';

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
  const clientRef = useRef(new ThalamusClient(options));
  const client = clientRef.current;
  const [token, setToken] = useState(null);
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  useEffect(() => {
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
  useEffect(() => {
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
  const login = useCallback(async (opts) => {
    setError(null);
    const verifier = client.auth.generateState();
    const challenge = await pkceChallenge(verifier);
    sessionStorage.setItem(`${storageKey}_verifier`, verifier);
    const url = client.auth.getAuthorizationUrl({ scope: opts?.scope, codeChallenge: challenge, codeChallengeMethod: "S256" });
    sessionStorage.setItem(`${storageKey}_state`, new URL(url).searchParams.get("state") || "");
    window.location.href = url;
  }, [storageKey]);
  const logout = useCallback(() => {
    localStorage.removeItem(storageKey);
    setToken(null);
    setUser(null);
  }, [storageKey]);
  const refreshToken = useCallback(async () => {
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
  const clientRef = useRef(new ThalamusClient({ clientId: "admin", redirectUri: "", baseUrl }));
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
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
  useEffect(() => {
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
function LoginButton({
  config,
  storageKey = "thalamus_auth",
  label = "Login with ZEA",
  scopes,
  className,
  style
}) {
  const { login, isAuthenticated, isLoading, error } = useThalamus({ ...config, storageKey });
  if (isLoading) return /* @__PURE__ */ jsx("span", { style: { color: "#8b949e", fontSize: 14 }, children: "Loading..." });
  if (isAuthenticated) return null;
  return /* @__PURE__ */ jsxs("div", { style: { display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }, children: [
    /* @__PURE__ */ jsx(
      "button",
      {
        onClick: () => login({ scope: scopes }),
        className,
        style: {
          padding: "12px 32px",
          borderRadius: 8,
          border: "none",
          cursor: "pointer",
          background: "#238636",
          color: "#fff",
          fontSize: 16,
          fontWeight: 600,
          fontFamily: "system-ui, sans-serif",
          ...style
        },
        children: label
      }
    ),
    error && /* @__PURE__ */ jsx("span", { style: { color: "#ff7b72", fontSize: 12 }, children: error })
  ] });
}
function RegisterButton({ config, orgName, appOrigin, label = "Create Account", className, style }) {
  const handleClick = () => {
    const authParams = new URLSearchParams({
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      response_type: "code",
      scope: (config.defaultScopes || ["openid", "profile", "email"]).join(" "),
      state: crypto.randomUUID()
    });
    if (orgName) authParams.set("org_name", orgName);
    if (appOrigin) authParams.set("app_origin", appOrigin);
    const returnTo = `/oauth/authorize?${authParams.toString()}`;
    window.location.href = `${config.baseUrl}/register?return_to=${encodeURIComponent(returnTo)}`;
  };
  return /* @__PURE__ */ jsx("button", { onClick: handleClick, className, style: { padding: "12px 32px", borderRadius: 8, border: "1px solid #30363d", cursor: "pointer", background: "transparent", color: "#e6edf3", fontSize: 16, fontWeight: 600, fontFamily: "system-ui, sans-serif", ...style }, children: label });
}
function UserMenu({ config, storageKey = "thalamus_auth", renderUser, className }) {
  const { user, logout, isAuthenticated, isLoading, token } = useThalamus({ ...config, storageKey });
  if (isLoading || !isAuthenticated || !user) return null;
  const initials = user.name ? user.name.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2) : (user.email || user.sub).slice(0, 2).toUpperCase();
  return /* @__PURE__ */ jsxs("div", { className, style: { display: "flex", alignItems: "center", gap: 10, fontFamily: "system-ui, sans-serif" }, children: [
    renderUser ? renderUser(user) : /* @__PURE__ */ jsxs(Fragment, { children: [
      /* @__PURE__ */ jsx("div", { style: {
        width: 28,
        height: 28,
        borderRadius: "50%",
        background: "#238636",
        color: "#fff",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: 11,
        fontWeight: 700,
        flexShrink: 0
      }, children: user.picture ? /* @__PURE__ */ jsx("img", { src: user.picture, alt: "", style: { width: 28, height: 28, borderRadius: "50%" } }) : initials }),
      /* @__PURE__ */ jsx("div", { style: { minWidth: 0 }, children: /* @__PURE__ */ jsx("div", { style: { fontSize: 12, fontWeight: 600, color: "#e6edf3", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }, children: user.name || user.email || user.sub }) })
    ] }),
    /* @__PURE__ */ jsx(
      "button",
      {
        onClick: logout,
        style: {
          background: "none",
          border: "1px solid #30363d",
          color: "#8b949e",
          padding: "4px 10px",
          borderRadius: 6,
          cursor: "pointer",
          fontSize: 11,
          fontFamily: "inherit"
        },
        children: "Logout"
      }
    )
  ] });
}
function UserCreateForm({ config, onCreated, className }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [isAgent, setIsAgent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const client = new ThalamusClient(config);
      const user = await client.admin.createUser({ email, password, name, is_agent: isAgent });
      setEmail("");
      setPassword("");
      setName("");
      setIsAgent(false);
      onCreated?.(user);
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };
  return /* @__PURE__ */ jsxs("form", { onSubmit: handleSubmit, className, style: { display: "flex", flexDirection: "column", gap: 12, fontFamily: "system-ui, sans-serif" }, children: [
    /* @__PURE__ */ jsxs("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }, children: [
      /* @__PURE__ */ jsx("input", { required: true, placeholder: "Email", type: "email", value: email, onChange: (e) => setEmail(e.target.value), className: "th-input" }),
      /* @__PURE__ */ jsx("input", { required: true, placeholder: "Password", type: "password", value: password, onChange: (e) => setPassword(e.target.value), className: "th-input", minLength: 8 }),
      /* @__PURE__ */ jsx("input", { placeholder: "Name (optional)", value: name, onChange: (e) => setName(e.target.value), className: "th-input" }),
      /* @__PURE__ */ jsxs("label", { style: { display: "flex", alignItems: "center", gap: 6, fontSize: 13, color: "#656d76", cursor: "pointer" }, children: [
        /* @__PURE__ */ jsx("input", { type: "checkbox", checked: isAgent, onChange: (e) => setIsAgent(e.target.checked) }),
        " Is Agent"
      ] })
    ] }),
    error && /* @__PURE__ */ jsx("div", { style: { padding: "8px 12px", background: "#fff0f0", borderRadius: 6, color: "#c00", fontSize: 12 }, children: error }),
    /* @__PURE__ */ jsx("button", { type: "submit", disabled: loading, className: "th-btn th-btn--primary", style: { alignSelf: "flex-start" }, children: loading ? "Creating..." : "Create User" })
  ] });
}
function UserTable({ users, loading, error, className }) {
  if (loading) return /* @__PURE__ */ jsx("p", { style: { color: "#656d76", fontSize: 13 }, children: "Loading..." });
  if (error) return /* @__PURE__ */ jsx("div", { style: { padding: "8px 12px", background: "#fff0f0", borderRadius: 6, color: "#c00", fontSize: 12 }, children: error });
  if (users.length === 0) return /* @__PURE__ */ jsx("p", { style: { color: "#656d76", fontSize: 13 }, children: "No users found." });
  return /* @__PURE__ */ jsx("div", { className, style: { border: "1px solid #d0d7de", borderRadius: 8, overflow: "hidden" }, children: /* @__PURE__ */ jsxs("table", { style: { width: "100%", borderCollapse: "collapse", fontSize: 13 }, children: [
    /* @__PURE__ */ jsx("thead", { children: /* @__PURE__ */ jsxs("tr", { style: { background: "#f6f8fa", textAlign: "left" }, children: [
      /* @__PURE__ */ jsx("th", { style: { padding: "8px 16px", fontWeight: 600 }, children: "Name" }),
      /* @__PURE__ */ jsx("th", { style: { padding: "8px 16px", fontWeight: 600 }, children: "Email" }),
      /* @__PURE__ */ jsx("th", { style: { padding: "8px 16px", fontWeight: 600 }, children: "Status" }),
      /* @__PURE__ */ jsx("th", { style: { padding: "8px 16px", fontWeight: 600 }, children: "Agent" })
    ] }) }),
    /* @__PURE__ */ jsx("tbody", { children: users.map((u) => /* @__PURE__ */ jsxs("tr", { style: { borderTop: "1px solid #d0d7de" }, children: [
      /* @__PURE__ */ jsx("td", { style: { padding: "8px 16px" }, children: u.name || "\u2014" }),
      /* @__PURE__ */ jsx("td", { style: { padding: "8px 16px", color: "#0969da" }, children: u.email }),
      /* @__PURE__ */ jsx("td", { style: { padding: "8px 16px" }, children: /* @__PURE__ */ jsx(StatusBadge, { status: u.status }) }),
      /* @__PURE__ */ jsx("td", { style: { padding: "8px 16px" }, children: u.is_agent ? "\u{1F916}" : "\u{1F464}" })
    ] }, u.id)) })
  ] }) });
}
function StatusBadge({ status }) {
  const colors = {
    active: { bg: "#dafbe1", color: "#1a7f37" },
    inactive: { bg: "#f6f8fa", color: "#656d76" },
    suspended: { bg: "#fff0f0", color: "#c00" }
  };
  const c = colors[status] || colors.inactive;
  return /* @__PURE__ */ jsx("span", { style: { padding: "2px 8px", borderRadius: 10, fontSize: 11, background: c.bg, color: c.color }, children: status || "unknown" });
}
function APIKeyManager({ baseUrl, authStorageKey = "thalamus_auth", label = "+ Generate API Key", className }) {
  const [keys, setKeys] = useState([]);
  const [newKey, setNewKey] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const token = typeof window !== "undefined" ? (() => {
    try {
      const s = localStorage.getItem(authStorageKey);
      return s ? JSON.parse(s).accessToken : "";
    } catch {
      return "";
    }
  })() : "";
  const createKey = async () => {
    setLoading(true);
    setError("");
    try {
      const res = await fetch(`${baseUrl}/api/v1/api-keys`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({ name: `key-${Date.now()}`, scopes: ["api:read", "api:write"] })
      });
      const data = await res.json();
      if (data.api_key) {
        setNewKey(data.api_key);
        setKeys((prev) => [...prev, { api_key: data.api_key, prefix: data.prefix, created: (/* @__PURE__ */ new Date()).toISOString() }]);
      } else setError(data.error || "Failed to create key");
    } catch (e) {
      setError(e.message);
    }
    setLoading(false);
  };
  const copyKey = (key) => {
    navigator.clipboard?.writeText(key);
  };
  return /* @__PURE__ */ jsxs("div", { className, style: { fontFamily: "system-ui, sans-serif" }, children: [
    error && /* @__PURE__ */ jsx("div", { style: { padding: "8px 12px", background: "#fff0f0", borderRadius: 6, color: "#c00", marginBottom: 12, fontSize: 12 }, children: error }),
    /* @__PURE__ */ jsx("button", { onClick: createKey, disabled: loading, style: {
      padding: "8px 20px",
      borderRadius: 6,
      border: "none",
      cursor: "pointer",
      background: "#238636",
      color: "#fff",
      fontSize: 13,
      fontWeight: 600,
      opacity: loading ? 0.7 : 1,
      fontFamily: "inherit"
    }, children: loading ? "Generating..." : label }),
    newKey && /* @__PURE__ */ jsxs("div", { style: { marginTop: 16, padding: "12px 16px", background: "#f0fff0", borderRadius: 8, border: "1px solid #2ea44f" }, children: [
      /* @__PURE__ */ jsx("div", { style: { fontSize: 12, fontWeight: 600, color: "#2ea44f", marginBottom: 6 }, children: "\u2705 Key created \u2014 copy it now" }),
      /* @__PURE__ */ jsxs("div", { style: { display: "flex", gap: 8, alignItems: "center" }, children: [
        /* @__PURE__ */ jsx("code", { style: { flex: 1, padding: "8px 12px", background: "#fff", borderRadius: 4, fontSize: 11, fontFamily: "monospace", wordBreak: "break-all", userSelect: "all" }, children: newKey }),
        /* @__PURE__ */ jsx("button", { onClick: () => copyKey(newKey), style: { padding: "6px 12px", borderRadius: 4, border: "1px solid #2ea44f", background: "#dafbe1", color: "#1a7f37", cursor: "pointer", fontSize: 11, fontFamily: "inherit" }, children: "Copy" })
      ] })
    ] }),
    keys.length > 0 && /* @__PURE__ */ jsxs("div", { style: { marginTop: 20 }, children: [
      /* @__PURE__ */ jsxs("div", { style: { fontSize: 12, fontWeight: 600, marginBottom: 8 }, children: [
        "Existing keys (",
        keys.length,
        ")"
      ] }),
      keys.map((k, i) => /* @__PURE__ */ jsxs("div", { style: { padding: "6px 0", borderBottom: "1px solid #eee", fontSize: 11, fontFamily: "monospace", color: "#656d76" }, children: [
        k.prefix,
        "...",
        k.api_key?.slice(-8),
        " \xB7 ",
        new Date(k.created).toLocaleDateString()
      ] }, i))
    ] })
  ] });
}
function OrgSwitcher({ config, onSwitch, className }) {
  const [orgs, setOrgs] = useState([]);
  const [selected, setSelected] = useState("");
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    const client = new ThalamusClient(config);
    client.admin.listOrganizations().then((o) => {
      setOrgs(o);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [config.baseUrl]);
  if (loading) return null;
  if (orgs.length === 0) return null;
  return /* @__PURE__ */ jsxs(
    "select",
    {
      className,
      value: selected,
      onChange: (e) => {
        setSelected(e.target.value);
        onSwitch?.(e.target.value);
      },
      style: {
        padding: "6px 12px",
        borderRadius: 6,
        border: "1px solid #30363d",
        background: "#161b22",
        color: "#e6edf3",
        fontSize: 13,
        fontFamily: "system-ui, sans-serif",
        cursor: "pointer",
        outline: "none"
      },
      children: [
        /* @__PURE__ */ jsx("option", { value: "", children: "Select org..." }),
        orgs.map((org) => /* @__PURE__ */ jsx("option", { value: org.id, children: org.name }, org.id))
      ]
    }
  );
}
function OrgManager({ config, className }) {
  const [orgs, setOrgs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  useEffect(() => {
    const client = new ThalamusClient(config);
    client.admin.listOrganizations().then((o) => {
      setOrgs(o);
      setLoading(false);
    }).catch((e) => {
      setError(e.message);
      setLoading(false);
    });
  }, [config.baseUrl]);
  if (loading) return /* @__PURE__ */ jsx("p", { style: { color: "#656d76", fontSize: 13 }, children: "Loading..." });
  if (error) return /* @__PURE__ */ jsx("div", { style: { padding: "8px 12px", background: "#fff0f0", borderRadius: 6, color: "#c00", fontSize: 12 }, children: error });
  if (orgs.length === 0) return /* @__PURE__ */ jsx("p", { style: { color: "#656d76", fontSize: 13 }, children: "No organizations." });
  return /* @__PURE__ */ jsx("div", { className, style: { display: "flex", flexDirection: "column", gap: 12, fontFamily: "system-ui, sans-serif" }, children: orgs.map((org) => /* @__PURE__ */ jsxs("div", { style: { padding: "16px", border: "1px solid #d0d7de", borderRadius: 8 }, children: [
    /* @__PURE__ */ jsx("div", { style: { fontWeight: 600, fontSize: 15 }, children: org.name }),
    /* @__PURE__ */ jsxs("div", { style: { fontSize: 12, color: "#656d76", marginTop: 4 }, children: [
      "Domains: ",
      (org.domains || []).join(", ") || "none"
    ] })
  ] }, org.id)) });
}
var Z = {
  mu: "#8b949e",
  pr: "#58a6ff"};
function ThalamusPanel({ config, onNavigate }) {
  const [view, setView] = useState("users");
  const handleNav = (v) => {
    setView(v);
    onNavigate?.(v);
  };
  const navItem = (v, label, icon) => /* @__PURE__ */ jsxs(
    "button",
    {
      onClick: () => handleNav(v),
      style: {
        display: "flex",
        alignItems: "center",
        gap: 8,
        width: "100%",
        padding: "6px 16px",
        border: "none",
        cursor: "pointer",
        background: view === v ? `${Z.pr}15` : "transparent",
        color: view === v ? Z.pr : Z.mu,
        fontSize: 13,
        fontFamily: "system-ui, sans-serif",
        textAlign: "left"
      },
      children: [
        /* @__PURE__ */ jsx("span", { style: { fontSize: 14, width: 20, textAlign: "center" }, children: icon }),
        label
      ]
    }
  );
  return /* @__PURE__ */ jsxs("div", { children: [
    navItem("users", "Users & Agents", "\u{1F464}"),
    navItem("orgs", "Organizations", "\u{1F3E2}"),
    navItem("apikeys", "API Keys", "\u{1F511}")
  ] });
}

export { APIKeyManager, AdminAPI, LoginButton, OAuth2, OrgManager, OrgSwitcher, RegisterButton, StatusBadge, ThalamusClient, ThalamusPanel, TokenManager, UserCreateForm, UserMenu, UserTable, useAdmin, useThalamus };
//# sourceMappingURL=index.mjs.map
//# sourceMappingURL=index.mjs.map