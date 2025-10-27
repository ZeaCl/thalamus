-- ============================================================================
-- ZEA Thalamus - Database Initialization Script
-- ============================================================================
-- This script runs automatically when PostgreSQL container starts for the
-- first time. It creates the database, user, and sets up initial permissions.
--
-- Note: This file is mounted in docker-compose.yml to:
--       /docker-entrypoint-initdb.d/init.sql
-- ============================================================================

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create extension for cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create thalamus user if not exists (for production)
DO
$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'thalamus') THEN
        CREATE ROLE thalamus WITH LOGIN PASSWORD 'change_me_in_production';
    END IF;
END
$$;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE thalamus_dev TO postgres;

-- Create development database if not exists
SELECT 'CREATE DATABASE thalamus_dev'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'thalamus_dev')\gexec

-- Create test database if not exists
SELECT 'CREATE DATABASE thalamus_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'thalamus_test')\gexec

-- Create production database if not exists (for local testing)
SELECT 'CREATE DATABASE thalamus_prod'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'thalamus_prod')\gexec

-- ============================================================================
-- Performance Tuning (Development)
-- ============================================================================
ALTER DATABASE thalamus_dev SET log_statement = 'all';
ALTER DATABASE thalamus_dev SET log_duration = true;
ALTER DATABASE thalamus_dev SET log_min_duration_statement = 100;

-- ============================================================================
-- Audit Log Table (Optional - for production audit persistence)
-- ============================================================================
-- Uncomment to enable database audit logging

/*
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100) NOT NULL,
    user_id UUID,
    resource_type VARCHAR(50),
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    node VARCHAR(255)
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_metadata ON audit_logs USING gin(metadata);
*/

-- ============================================================================
-- Session Store Table (Optional - for distributed sessions)
-- ============================================================================
-- Uncomment if using database for session storage instead of Redis

/*
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id VARCHAR(255) UNIQUE NOT NULL,
    data JSONB NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);

-- Auto-cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM sessions WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;
*/

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Function to generate random secure token
CREATE OR REPLACE FUNCTION generate_token(length INTEGER DEFAULT 32)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(gen_random_bytes(length), 'hex');
END;
$$ LANGUAGE plpgsql;

-- Function to get database size
CREATE OR REPLACE FUNCTION get_db_size()
RETURNS TABLE(database_name TEXT, size TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT datname::TEXT,
           pg_size_pretty(pg_database_size(datname))
    FROM pg_database
    WHERE datname LIKE 'thalamus%'
    ORDER BY pg_database_size(datname) DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Statistics and Monitoring Views
-- ============================================================================

-- View for table sizes
CREATE OR REPLACE VIEW table_sizes AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY size_bytes DESC;

-- ============================================================================
-- Completion Message
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'ZEA Thalamus Database Initialization Complete';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Databases created: thalamus_dev, thalamus_test, thalamus_prod';
    RAISE NOTICE 'Extensions installed: uuid-ossp, pgcrypto';
    RAISE NOTICE 'Helper functions available: generate_token(), get_db_size()';
    RAISE NOTICE '=================================================================';
END $$;
