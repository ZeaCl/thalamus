--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18 (Homebrew)
-- Dumped by pg_dump version 14.18 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_api_keys (
    id uuid NOT NULL,
    key_hash character varying(255) NOT NULL,
    key_prefix character varying(13) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    scopes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    expires_at timestamp without time zone,
    last_used_at timestamp without time zone,
    created_by_user_id uuid,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: agent_skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_skills (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text NOT NULL,
    instructions text NOT NULL,
    execution_type character varying(255) NOT NULL,
    execution_endpoint character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: agent_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_tokens (
    id uuid NOT NULL,
    client_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    access_token character varying(255) NOT NULL,
    agent_type character varying(50) NOT NULL,
    task_id uuid NOT NULL,
    task_description text NOT NULL,
    scopes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    parent_agent_id uuid,
    delegation_chain jsonb DEFAULT '{}'::jsonb NOT NULL,
    delegation_depth integer DEFAULT 0 NOT NULL,
    delegator_user_id uuid NOT NULL,
    expires_in integer NOT NULL,
    expires_at timestamp(0) without time zone NOT NULL,
    revoked_at timestamp(0) without time zone,
    revoke_reason text,
    reason text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT valid_agent_type CHECK (((agent_type)::text = ANY ((ARRAY['autonomous'::character varying, 'supervisor'::character varying, 'tool'::character varying])::text[]))),
    CONSTRAINT valid_delegation_depth CHECK (((delegation_depth >= 0) AND (delegation_depth < 5)))
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid NOT NULL,
    event_type character varying(255) NOT NULL,
    user_id uuid,
    organization_id uuid,
    client_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb,
    ip_address character varying(255),
    user_agent text,
    request_id character varying(255),
    environment character varying(255),
    node character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: domain_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.domain_scopes (
    id uuid NOT NULL,
    domain character varying(255) NOT NULL,
    scope character varying(255) NOT NULL,
    description text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: oauth2_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth2_clients (
    id uuid NOT NULL,
    client_id_string character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    client_type character varying(255) NOT NULL,
    client_secret character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    allowed_grant_types character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    allowed_scopes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    redirect_uris character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    description text,
    logo_url character varying(255),
    terms_of_service_url character varying(255),
    privacy_policy_url character varying(255),
    pkce_required boolean DEFAULT false NOT NULL,
    token_endpoint_auth_method character varying(255) DEFAULT 'client_secret_post'::character varying NOT NULL,
    access_token_lifetime integer DEFAULT 3600 NOT NULL,
    refresh_token_lifetime integer DEFAULT 2592000 NOT NULL,
    authorization_code_lifetime integer DEFAULT 600 NOT NULL,
    organization_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags text[] DEFAULT ARRAY[]::text[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oban_jobs IS '12';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'trial'::character varying NOT NULL,
    verified boolean DEFAULT false NOT NULL,
    plan_type character varying(255) DEFAULT 'free'::character varying NOT NULL,
    max_users integer NOT NULL,
    max_api_calls_per_month integer NOT NULL,
    mfa_required boolean DEFAULT false NOT NULL,
    sso_enabled boolean DEFAULT false NOT NULL,
    audit_logs_retention_days integer DEFAULT 30 NOT NULL,
    support_level character varying(255) DEFAULT 'community'::character varying NOT NULL,
    current_user_count integer DEFAULT 0 NOT NULL,
    api_calls_current_month integer DEFAULT 0 NOT NULL,
    api_calls_reset_at timestamp(0) without time zone NOT NULL,
    members jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    domains character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    owner_email character varying(255)
);


--
-- Name: personal_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personal_access_tokens (
    id uuid NOT NULL,
    token_hash character varying(255) NOT NULL,
    token_prefix character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    scopes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    expires_at timestamp without time zone,
    last_used_at timestamp without time zone,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: project_contexts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_contexts (
    id uuid NOT NULL,
    project_id uuid NOT NULL,
    file_name character varying(255) NOT NULL,
    content text NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    scopes character varying(255)[] DEFAULT ARRAY[]::character varying[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT roles_description_length CHECK (((description IS NULL) OR (char_length(description) <= 500))),
    CONSTRAINT roles_name_length CHECK (((char_length((name)::text) >= 1) AND (char_length((name)::text) <= 100)))
);


--
-- Name: saml_identity_providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saml_identity_providers (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    idp_entity_id character varying(255) NOT NULL,
    idp_sso_url character varying(255) NOT NULL,
    idp_slo_url character varying(255),
    idp_certificate text NOT NULL,
    sp_entity_id character varying(255),
    idp_metadata_xml text,
    enabled boolean DEFAULT true NOT NULL,
    force_saml boolean DEFAULT false NOT NULL,
    jit_provisioning boolean DEFAULT true NOT NULL,
    allowed_domains character varying(255)[] DEFAULT ARRAY[]::character varying[],
    attribute_mapping jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: secrets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.secrets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type character varying(255) NOT NULL,
    owner_id uuid NOT NULL,
    provider character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    encrypted_value bytea NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tokens (
    id uuid NOT NULL,
    token text NOT NULL,
    type character varying(255) NOT NULL,
    scopes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    expires_at timestamp(0) without time zone NOT NULL,
    revoked boolean DEFAULT false NOT NULL,
    revoked_at timestamp(0) without time zone,
    code_challenge character varying(255),
    code_challenge_method character varying(255),
    token_family_id uuid,
    user_id uuid,
    client_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    organization_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb,
    agent_type character varying(255),
    delegated_by_user_id uuid,
    delegation_chain uuid[] DEFAULT ARRAY[]::uuid[],
    task_id character varying(255),
    task_type character varying(255),
    task_scopes character varying(255)[] DEFAULT ARRAY[]::character varying[],
    max_operations integer,
    operations_count integer DEFAULT 0,
    expires_on_completion boolean DEFAULT false,
    intent_description text,
    orchestrator_id character varying(255),
    environment character varying(255),
    CONSTRAINT tokens_agent_type_check CHECK (((agent_type IS NULL) OR ((agent_type)::text = ANY ((ARRAY['autonomous'::character varying, 'supervisor'::character varying, 'tool'::character varying])::text[]))))
);


--
-- Name: user_domain_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_domain_roles (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    domain character varying(255) NOT NULL,
    role character varying(255) NOT NULL,
    scopes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    entity_id character varying(255)
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    assigned_by uuid,
    assigned_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'pending_verification'::character varying NOT NULL,
    verified_at timestamp(0) without time zone,
    last_login_at timestamp(0) without time zone,
    failed_login_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp(0) without time zone,
    mfa_methods jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    organization_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    name character varying(255),
    avatar_url character varying(255),
    is_agent boolean DEFAULT false NOT NULL,
    agent_config jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: admin_api_keys admin_api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_api_keys
    ADD CONSTRAINT admin_api_keys_pkey PRIMARY KEY (id);


--
-- Name: agent_skills agent_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_skills
    ADD CONSTRAINT agent_skills_pkey PRIMARY KEY (id);


--
-- Name: agent_tokens agent_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_tokens
    ADD CONSTRAINT agent_tokens_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: domain_scopes domain_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_scopes
    ADD CONSTRAINT domain_scopes_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs non_negative_priority; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.oban_jobs
    ADD CONSTRAINT non_negative_priority CHECK ((priority >= 0)) NOT VALID;


--
-- Name: oauth2_clients oauth2_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_clients
    ADD CONSTRAINT oauth2_clients_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: project_contexts project_contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_contexts
    ADD CONSTRAINT project_contexts_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: saml_identity_providers saml_identity_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saml_identity_providers
    ADD CONSTRAINT saml_identity_providers_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: secrets secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secrets
    ADD CONSTRAINT secrets_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: user_domain_roles user_domain_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_domain_roles
    ADD CONSTRAINT user_domain_roles_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: admin_api_keys_created_by_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_api_keys_created_by_user_id_index ON public.admin_api_keys USING btree (created_by_user_id);


--
-- Name: admin_api_keys_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_api_keys_expires_at_index ON public.admin_api_keys USING btree (expires_at);


--
-- Name: admin_api_keys_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_api_keys_is_active_index ON public.admin_api_keys USING btree (is_active);


--
-- Name: admin_api_keys_key_prefix_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admin_api_keys_key_prefix_index ON public.admin_api_keys USING btree (key_prefix);


--
-- Name: agent_skills_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX agent_skills_name_index ON public.agent_skills USING btree (name);


--
-- Name: audit_logs_client_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_client_id_index ON public.audit_logs USING btree (client_id);


--
-- Name: audit_logs_event_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_event_type_index ON public.audit_logs USING btree (event_type);


--
-- Name: audit_logs_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_inserted_at_index ON public.audit_logs USING btree (inserted_at);


--
-- Name: audit_logs_ip_address_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_ip_address_index ON public.audit_logs USING btree (ip_address);


--
-- Name: audit_logs_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_organization_id_index ON public.audit_logs USING btree (organization_id);


--
-- Name: audit_logs_organization_id_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_organization_id_inserted_at_index ON public.audit_logs USING btree (organization_id, inserted_at);


--
-- Name: audit_logs_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_user_id_index ON public.audit_logs USING btree (user_id);


--
-- Name: audit_logs_user_id_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_user_id_inserted_at_index ON public.audit_logs USING btree (user_id, inserted_at);


--
-- Name: domain_scopes_domain_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX domain_scopes_domain_index ON public.domain_scopes USING btree (domain);


--
-- Name: domain_scopes_domain_scope_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX domain_scopes_domain_scope_index ON public.domain_scopes USING btree (domain, scope);


--
-- Name: idx_agent_tokens_access_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_tokens_access_token ON public.agent_tokens USING btree (access_token) WHERE (revoked_at IS NULL);


--
-- Name: idx_agent_tokens_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_tokens_active ON public.agent_tokens USING btree (client_id, organization_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_agent_tokens_delegation_chain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_tokens_delegation_chain ON public.agent_tokens USING gin (delegation_chain);


--
-- Name: idx_agent_tokens_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_tokens_expires_at ON public.agent_tokens USING btree (expires_at) WHERE (revoked_at IS NULL);


--
-- Name: idx_agent_tokens_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_tokens_organization_id ON public.agent_tokens USING btree (organization_id);


--
-- Name: idx_agent_tokens_parent_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_tokens_parent_agent_id ON public.agent_tokens USING btree (parent_agent_id) WHERE (parent_agent_id IS NOT NULL);


--
-- Name: idx_agent_tokens_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_tokens_task_id ON public.agent_tokens USING btree (task_id);


--
-- Name: oauth2_clients_client_id_string_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX oauth2_clients_client_id_string_index ON public.oauth2_clients USING btree (client_id_string);


--
-- Name: oauth2_clients_client_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_clients_client_type_index ON public.oauth2_clients USING btree (client_type);


--
-- Name: oauth2_clients_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_clients_is_active_index ON public.oauth2_clients USING btree (is_active);


--
-- Name: oauth2_clients_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_clients_organization_id_index ON public.oauth2_clients USING btree (organization_id);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON public.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: organizations_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organizations_name_index ON public.organizations USING btree (name);


--
-- Name: organizations_plan_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organizations_plan_type_index ON public.organizations USING btree (plan_type);


--
-- Name: organizations_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organizations_status_index ON public.organizations USING btree (status);


--
-- Name: organizations_verified_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organizations_verified_index ON public.organizations USING btree (verified);


--
-- Name: personal_access_tokens_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX personal_access_tokens_is_active_index ON public.personal_access_tokens USING btree (is_active);


--
-- Name: personal_access_tokens_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX personal_access_tokens_organization_id_index ON public.personal_access_tokens USING btree (organization_id);


--
-- Name: personal_access_tokens_token_prefix_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX personal_access_tokens_token_prefix_index ON public.personal_access_tokens USING btree (token_prefix);


--
-- Name: personal_access_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX personal_access_tokens_user_id_index ON public.personal_access_tokens USING btree (user_id);


--
-- Name: project_contexts_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_contexts_project_id_index ON public.project_contexts USING btree (project_id);


--
-- Name: projects_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_name_index ON public.projects USING btree (name);


--
-- Name: roles_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roles_organization_id_index ON public.roles USING btree (organization_id);


--
-- Name: roles_organization_id_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX roles_organization_id_name_index ON public.roles USING btree (organization_id, name);


--
-- Name: saml_identity_providers_enabled_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saml_identity_providers_enabled_index ON public.saml_identity_providers USING btree (enabled);


--
-- Name: saml_identity_providers_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX saml_identity_providers_organization_id_index ON public.saml_identity_providers USING btree (organization_id);


--
-- Name: secrets_owner_type_owner_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX secrets_owner_type_owner_id_index ON public.secrets USING btree (owner_type, owner_id);


--
-- Name: secrets_provider_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX secrets_provider_index ON public.secrets USING btree (provider);


--
-- Name: tokens_agent_type_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_agent_type_expires_at_index ON public.tokens USING btree (agent_type, expires_at);


--
-- Name: tokens_agent_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_agent_type_index ON public.tokens USING btree (agent_type);


--
-- Name: tokens_client_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_client_id_index ON public.tokens USING btree (client_id);


--
-- Name: tokens_client_id_type_revoked_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_client_id_type_revoked_index ON public.tokens USING btree (client_id, type, revoked);


--
-- Name: tokens_delegated_by_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_delegated_by_user_id_index ON public.tokens USING btree (delegated_by_user_id);


--
-- Name: tokens_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_expires_at_index ON public.tokens USING btree (expires_at);


--
-- Name: tokens_orchestrator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_orchestrator_id_index ON public.tokens USING btree (orchestrator_id);


--
-- Name: tokens_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_organization_id_index ON public.tokens USING btree (organization_id);


--
-- Name: tokens_revoked_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_revoked_index ON public.tokens USING btree (revoked);


--
-- Name: tokens_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_task_id_index ON public.tokens USING btree (task_id);


--
-- Name: tokens_token_family_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_token_family_id_index ON public.tokens USING btree (token_family_id);


--
-- Name: tokens_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tokens_token_index ON public.tokens USING btree (token);


--
-- Name: tokens_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_type_index ON public.tokens USING btree (type);


--
-- Name: tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_user_id_index ON public.tokens USING btree (user_id);


--
-- Name: tokens_user_id_type_revoked_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tokens_user_id_type_revoked_index ON public.tokens USING btree (user_id, type, revoked);


--
-- Name: user_domain_roles_user_id_organization_id_domain_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_domain_roles_user_id_organization_id_domain_index ON public.user_domain_roles USING btree (user_id, organization_id, domain);


--
-- Name: user_domain_roles_user_id_organization_id_domain_role_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_domain_roles_user_id_organization_id_domain_role_index ON public.user_domain_roles USING btree (user_id, organization_id, domain, role);


--
-- Name: user_roles_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_roles_role_id_index ON public.user_roles USING btree (role_id);


--
-- Name: user_roles_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_roles_user_id_index ON public.user_roles USING btree (user_id);


--
-- Name: user_roles_user_id_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_roles_user_id_role_id_index ON public.user_roles USING btree (user_id, role_id);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: users_last_login_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_last_login_at_index ON public.users USING btree (last_login_at);


--
-- Name: users_locked_until_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_locked_until_index ON public.users USING btree (locked_until);


--
-- Name: users_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_name_index ON public.users USING btree (name);


--
-- Name: users_organization_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_organization_id_index ON public.users USING btree (organization_id);


--
-- Name: users_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_status_index ON public.users USING btree (status);


--
-- Name: users_verified_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_verified_at_index ON public.users USING btree (verified_at);


--
-- Name: admin_api_keys admin_api_keys_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_api_keys
    ADD CONSTRAINT admin_api_keys_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: agent_tokens agent_tokens_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_tokens
    ADD CONSTRAINT agent_tokens_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.oauth2_clients(id) ON DELETE RESTRICT;


--
-- Name: agent_tokens agent_tokens_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_tokens
    ADD CONSTRAINT agent_tokens_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: agent_tokens agent_tokens_parent_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_tokens
    ADD CONSTRAINT agent_tokens_parent_agent_id_fkey FOREIGN KEY (parent_agent_id) REFERENCES public.agent_tokens(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.oauth2_clients(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: oauth2_clients oauth2_clients_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_clients
    ADD CONSTRAINT oauth2_clients_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: personal_access_tokens personal_access_tokens_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: personal_access_tokens personal_access_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: project_contexts project_contexts_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_contexts
    ADD CONSTRAINT project_contexts_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: roles roles_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: saml_identity_providers saml_identity_providers_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saml_identity_providers
    ADD CONSTRAINT saml_identity_providers_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: tokens tokens_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.oauth2_clients(id) ON DELETE CASCADE;


--
-- Name: tokens tokens_delegated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_delegated_by_user_id_fkey FOREIGN KEY (delegated_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: tokens tokens_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE SET NULL;


--
-- Name: tokens tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20251026000001);
INSERT INTO public."schema_migrations" (version) VALUES (20251026000002);
INSERT INTO public."schema_migrations" (version) VALUES (20251026000003);
INSERT INTO public."schema_migrations" (version) VALUES (20251026000004);
INSERT INTO public."schema_migrations" (version) VALUES (20251209153633);
INSERT INTO public."schema_migrations" (version) VALUES (20251209153639);
INSERT INTO public."schema_migrations" (version) VALUES (20251224000001);
INSERT INTO public."schema_migrations" (version) VALUES (20251225114444);
INSERT INTO public."schema_migrations" (version) VALUES (20260102172221);
INSERT INTO public."schema_migrations" (version) VALUES (20260102210319);
INSERT INTO public."schema_migrations" (version) VALUES (20260102212619);
INSERT INTO public."schema_migrations" (version) VALUES (20260117014403);
INSERT INTO public."schema_migrations" (version) VALUES (20260118001430);
INSERT INTO public."schema_migrations" (version) VALUES (20260120133221);
INSERT INTO public."schema_migrations" (version) VALUES (20260120165420);
INSERT INTO public."schema_migrations" (version) VALUES (20260122125819);
INSERT INTO public."schema_migrations" (version) VALUES (20260523123000);
INSERT INTO public."schema_migrations" (version) VALUES (20260524000001);
INSERT INTO public."schema_migrations" (version) VALUES (20260524000002);
INSERT INTO public."schema_migrations" (version) VALUES (20260526000001);
INSERT INTO public."schema_migrations" (version) VALUES (20260602233423);
INSERT INTO public."schema_migrations" (version) VALUES (20260603144655);
INSERT INTO public."schema_migrations" (version) VALUES (20260604021445);
INSERT INTO public."schema_migrations" (version) VALUES (20260605194100);
INSERT INTO public."schema_migrations" (version) VALUES (20260623000001);
