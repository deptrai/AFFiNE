-- PostgreSQL initialization script for AFFiNE
-- This script sets up the database with proper encoding and extensions

-- Ensure UTF-8 encoding
SET client_encoding = 'UTF8';

-- Create extensions if they don't exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create indexes for better performance
-- These will be created by the application, but we can prepare the database

-- Set timezone
SET timezone = 'UTC';

-- Create application user if not exists (for future use)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'affine_app') THEN
        CREATE ROLE affine_app WITH LOGIN PASSWORD 'affine_app_password';
    END IF;
END
$$;

-- Grant necessary permissions
GRANT CONNECT ON DATABASE affine TO affine_app;
GRANT USAGE ON SCHEMA public TO affine_app;
GRANT CREATE ON SCHEMA public TO affine_app;

-- Log initialization
INSERT INTO pg_stat_statements_info (dealloc) VALUES (0) ON CONFLICT DO NOTHING;

-- Optimize PostgreSQL settings for AFFiNE workload
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Create a function to log database events
CREATE OR REPLACE FUNCTION log_database_event(event_type TEXT, event_data JSONB DEFAULT '{}')
RETURNS VOID AS $$
BEGIN
    -- This can be extended to log to a table or external system
    RAISE NOTICE 'Database Event: % - %', event_type, event_data;
END;
$$ LANGUAGE plpgsql;

-- Log successful initialization
SELECT log_database_event('INIT_COMPLETE', '{"timestamp": "' || NOW() || '"}');

-- Create a health check function
CREATE OR REPLACE FUNCTION health_check()
RETURNS TABLE(status TEXT, timestamp TIMESTAMPTZ) AS $$
BEGIN
    RETURN QUERY SELECT 'healthy'::TEXT, NOW();
END;
$$ LANGUAGE plpgsql;
