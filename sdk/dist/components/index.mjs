import { useState, useEffect, useRef, useCallback } from 'react';
import { jsx, jsxs, Fragment } from 'react/jsx-runtime';

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
  const { user, logout, isAuthenticated, isLoading} = useThalamus({ ...config, storageKey });
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

export { APIKeyManager, LoginButton, OrgManager, OrgSwitcher, RegisterButton, StatusBadge, UserCreateForm, UserMenu, UserTable };
//# sourceMappingURL=index.mjs.map
//# sourceMappingURL=index.mjs.map