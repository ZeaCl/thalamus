'use strict';

var react = require('react');

// src/hooks/useThalamus.ts

// src/client/OAuth2.ts
var OAuth2 = class {
  constructor(config) {
    this.config = config;
  }
  config;
  getAuthorizationUrl(options) {
    const { scope = this.config.defaultScopes || ["openid", "profile", "email"], state = this.generateState(), codeChallenge, codeChallengeMethod } = options || {};
    const params = new URLSearchParams({
      response_type: "code",
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
  async exchangeCode(codeOrOptions) {
    const code = typeof codeOrOptions === "string" ? codeOrOptions : codeOrOptions.code;
    const codeVerifier = typeof codeOrOptions === "string" ? void 0 : codeOrOptions.codeVerifier;
    const body = { grant_type: "authorization_code", code, client_id: this.config.clientId, redirect_uri: this.config.redirectUri };
    if (this.config.clientSecret) body.client_secret = this.config.clientSecret;
    if (codeVerifier) body.code_verifier = codeVerifier;
    return this.requestToken(body);
  }
  async getClientCredentialsToken(options) {
    const { scope = this.config.defaultScopes || [] } = options || {};
    const body = { grant_type: "client_credentials", client_id: this.config.clientId, client_secret: this.config.clientSecret };
    if (scope.length > 0) body.scope = Array.isArray(scope) ? scope.join(" ") : scope;
    return this.requestToken(body);
  }
  async refreshToken(options) {
    return this.requestToken({ grant_type: "refresh_token", refresh_token: options.refreshToken, client_id: this.config.clientId, client_secret: this.config.clientSecret });
  }
  generateState() {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Array.from(array, (b) => b.toString(16).padStart(2, "0")).join("");
  }
  async requestToken(body) {
    const res = await fetch(`${this.config.baseUrl}/oauth/token`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    if (!res.ok) throw await this.toError(res);
    return res.json();
  }
  async toError(res) {
    let data = {};
    try {
      data = await res.json();
    } catch {
    }
    const err = new Error(data.error_description || data.message || `HTTP ${res.status}`);
    err.statusCode = res.status;
    err.error = data.error;
    err.error_description = data.error_description;
    return err;
  }
};

// src/client/TokenManager.ts
var TokenManager = class {
  constructor(config) {
    this.config = config;
  }
  config;
  async introspect(token) {
    const res = await fetch(`${this.config.baseUrl}/oauth/introspect`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token }) });
    if (!res.ok) throw await this.toError(res);
    return res.json();
  }
  async getUserInfo(accessToken) {
    const res = await fetch(`${this.config.baseUrl}/oauth/userinfo`, { headers: { Authorization: `Bearer ${accessToken}` } });
    if (!res.ok) throw await this.toError(res);
    return res.json();
  }
  async validate(token) {
    try {
      return (await this.introspect(token)).active === true;
    } catch {
      return false;
    }
  }
  async toError(res) {
    let data = {};
    try {
      data = await res.json();
    } catch {
    }
    const err = new Error(data.error_description || data.message || `HTTP ${res.status}`);
    err.statusCode = res.status;
    err.error = data.error;
    err.error_description = data.error_description;
    return err;
  }
};

// src/client/AdminAPI.ts
var AdminAPI = class {
  constructor(config) {
    this.config = config;
  }
  config;
  getAccessToken() {
    try {
      const saved = localStorage.getItem("thalamus_auth");
      return saved ? JSON.parse(saved).accessToken : null;
    } catch {
      return null;
    }
  }
  async request(url, opts = {}) {
    const token = this.getAccessToken();
    const res = await fetch(url, { ...opts, headers: { "Content-Type": "application/json", ...token ? { Authorization: `Bearer ${token}` } : {}, ...opts.headers } });
    if (!res.ok) throw await this.toError(res);
    return res;
  }
  async toError(res) {
    let data = {};
    try {
      data = await res.json();
    } catch {
    }
    const err = new Error(data.error_description || data.error || `HTTP ${res.status}`);
    err.statusCode = res.status;
    err.error = data.error;
    err.error_description = data.error_description;
    return err;
  }
  // ── Users ──
  async listUsers() {
    const r = await this.request(`${this.config.baseUrl}/api/users`);
    const j = await r.json();
    return j.data ?? j;
  }
  async listAgents() {
    const users = await this.listUsers();
    return users.filter((u) => u.is_agent);
  }
  async getUser(id) {
    const r = await this.request(`${this.config.baseUrl}/api/users/${id}`);
    const j = await r.json();
    return j.data ?? j;
  }
  async createUser(data) {
    const r = await this.request(`${this.config.baseUrl}/api/users`, { method: "POST", body: JSON.stringify({ user: data }) });
    const j = await r.json();
    return j.data ?? j;
  }
  async updateUser(id, data) {
    const r = await this.request(`${this.config.baseUrl}/api/users/${id}`, { method: "PATCH", body: JSON.stringify({ user: data }) });
    const j = await r.json();
    return j.data ?? j;
  }
  // ── Organizations ──
  async listOrganizations() {
    const r = await this.request(`${this.config.baseUrl}/api/organizations`);
    const j = await r.json();
    return j.data ?? j;
  }
  async getOrganization(id) {
    const r = await this.request(`${this.config.baseUrl}/api/organizations/${id}`);
    const j = await r.json();
    return j.data ?? j;
  }
  async addOrgMember(orgId, userId) {
    const r = await this.request(`${this.config.baseUrl}/api/organizations/${orgId}/members`, { method: "POST", body: JSON.stringify({ user_id: userId }) });
    return r.json();
  }
  // ── Roles ──
  async listRoles() {
    const r = await this.request(`${this.config.baseUrl}/api/roles`);
    const j = await r.json();
    return j.data ?? j;
  }
  // ── Domain Roles ──
  async listDomainRoles(filters) {
    const p = new URLSearchParams();
    if (filters?.user_id) p.set("user_id", filters.user_id);
    if (filters?.organization_id) p.set("organization_id", filters.organization_id);
    if (filters?.domain) p.set("domain", filters.domain);
    const qs = p.toString();
    const r = await this.request(`${this.config.baseUrl}/api/domains/roles${qs ? `?${qs}` : ""}`);
    const j = await r.json();
    return j.data ?? j;
  }
  async grantDomainRole(p) {
    const r = await this.request(`${this.config.baseUrl}/api/domains/roles/grant`, { method: "POST", body: JSON.stringify(p) });
    return r.json();
  }
  async revokeDomainRole(p) {
    const r = await this.request(`${this.config.baseUrl}/api/domains/roles/revoke`, { method: "DELETE", body: JSON.stringify(p) });
    return r.json();
  }
};

// src/client/ThalamusClient.ts
var ThalamusClient = class {
  auth;
  tokens;
  admin;
  config;
  constructor(config) {
    if (!config.clientId) throw new Error("clientId is required");
    if (!config.redirectUri) throw new Error("redirectUri is required");
    if (!config.baseUrl) throw new Error("baseUrl is required");
    config.baseUrl = config.baseUrl.replace(/\/$/, "");
    this.config = config;
    this.auth = new OAuth2(config);
    this.tokens = new TokenManager(config);
    this.admin = new AdminAPI(config);
  }
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