-- This adaptation is released under the MIT License.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SEQUENCE epoch_seq INCREMENT BY 1 MAXVALUE 9 CYCLE;
CREATE OR REPLACE FUNCTION generate_object_id() RETURNS varchar AS $$
DECLARE
    time_component bigint;
    epoch_seq int;
    machine_id text := encode(gen_random_bytes(3), 'hex');
    process_id bigint;
    seq_id text := encode(gen_random_bytes(3), 'hex');
    result varchar:= '';
BEGIN
    SELECT FLOOR(EXTRACT(EPOCH FROM clock_timestamp())) INTO time_component;
    SELECT nextval('epoch_seq') INTO epoch_seq;
    SELECT pg_backend_pid() INTO process_id;

    result := result || lpad(to_hex(time_component), 8, '0');
    result := result || machine_id;
    result := result || lpad(to_hex(process_id), 4, '0');
    result := result || seq_id;
    result := result || epoch_seq;
    RETURN result;
END;
$$ LANGUAGE PLPGSQL;

CREATE TYPE "user_perm" AS ENUM ('default', 'admin');
CREATE TYPE "member_role" AS ENUM ('guest', 'developer', 'admin');

CREATE TABLE IF NOT EXISTS "user" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    perm user_perm NOT NULL DEFAULT 'default',
    name VARCHAR(128) UNIQUE NOT NULL,
    first_name VARCHAR(128) NOT NULL,
    last_name VARCHAR(128) NOT NULL,
    email VARCHAR(256) UNIQUE DEFAULT NULL,
    password VARCHAR(1024) NOT NULL,
    config TEXT DEFAULT '{}',
    api_token VARCHAR(256) DEFAULT NULL,
    github_username VARCHAR(128) UNIQUE DEFAULT NULL,
    is_email_verified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS "organization" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    name VARCHAR(128) UNIQUE NOT NULL,
    description TEXT,
    config TEXT DEFAULT '{}',
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS "user_group" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    name VARCHAR(128) NOT NULL,
    organization_id INTEGER NOT NULL REFERENCES "organization"("id") ON DELETE CASCADE,
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX "uk_userGroup_orgId_name" ON "user_group" ("organization_id", "name");

CREATE TABLE IF NOT EXISTS "organization_member" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    organization_id INTEGER NOT NULL REFERENCES "organization"("id") ON DELETE CASCADE,
    user_group_id INTEGER REFERENCES "user_group"("id") ON DELETE CASCADE,
    user_id INTEGER REFERENCES "user"("id") ON DELETE CASCADE,
    role member_role NOT NULL DEFAULT 'guest',
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX "uk_orgMember_orgId_userGroupId_userId" ON "organization_member" ("organization_id", "user_group_id", "user_id");

CREATE TABLE IF NOT EXISTS "user_group_user_relation" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    user_group_id INTEGER NOT NULL REFERENCES "user_group"("id") ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS "cluster" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    name VARCHAR(128) NOT NULL,
    description TEXT,
    organization_id INTEGER NOT NULL REFERENCES "organization"("id") ON DELETE CASCADE,
    kube_config TEXT NOT NULL,
    config TEXT DEFAULT '{}',
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX "uk_cluster_orgId_name" ON "cluster" ("organization_id", "name");

CREATE TABLE IF NOT EXISTS "cluster_member" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    cluster_id INTEGER NOT NULL REFERENCES "cluster"("id") ON DELETE CASCADE,
    user_group_id INTEGER REFERENCES "user_group"("id") ON DELETE CASCADE,
    user_id INTEGER REFERENCES "user"("id") ON DELETE CASCADE,
    role member_role NOT NULL DEFAULT 'guest',
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX "uk_clusterMember_userGroupId_userId" ON "cluster_member" ("cluster_id", "user_group_id", "user_id");

CREATE TABLE IF NOT EXISTS "bundle" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    name VARCHAR(128) NOT NULL,
    description TEXT,
    organization_id INTEGER NOT NULL REFERENCES "organization"("id") ON DELETE CASCADE,
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX "uk_bundle_orgId_name" ON "bundle" ("organization_id", "name");

CREATE TYPE "bundle_version_upload_status" AS ENUM ('pending', 'uploading', 'success', 'failed');
CREATE TYPE "bundle_version_build_status" AS ENUM ('pending', 'building', 'success', 'failed');

CREATE TABLE IF NOT EXISTS "bundle_version" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    version VARCHAR(512) NOT NULL,
    description TEXT,
    file_path TEXT,
    bundle_id INTEGER NOT NULL REFERENCES "bundle"("id") ON DELETE CASCADE,
    upload_status bundle_version_upload_status NOT NULL DEFAULT 'pending',
    build_status bundle_version_build_status NOT NULL DEFAULT 'pending',
    upload_started_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    upload_finished_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    upload_finished_reason TEXT,
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX "uk_bundleVersion_bundleId_version" ON "bundle_version" ("bundle_id", "version");

CREATE TYPE "deployment_status" AS ENUM ('unknown', 'non-deployed', 'failed', 'unhealthy', 'deploying', 'running');

CREATE TABLE IF NOT EXISTS "deployment" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    name VARCHAR(128) NOT NULL,
    description TEXT,
    cluster_id INTEGER NOT NULL REFERENCES "cluster"("id") ON DELETE CASCADE,
    status deployment_status NOT NULL DEFAULT 'non-deployed',
    status_syncing_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    status_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX "uk_deployment_clusterId_name" ON "deployment" ("cluster_id", "name");

CREATE TABLE IF NOT EXISTS "deployment_snapshot" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    deployment_id INTEGER NOT NULL REFERENCES "deployment"("id") ON DELETE CASCADE,
    bundle_version_id INTEGER REFERENCES "bundle_version"("id") ON DELETE CASCADE,
    config TEXT DEFAULT '{}',
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TYPE "resource_type" AS ENUM ('organization', 'cluster', 'bundle', 'bundle_version', 'deployment', 'deployment_snapshot');

CREATE TABLE IF NOT EXISTS "event" (
    id SERIAL PRIMARY KEY,
    uid VARCHAR(32) UNIQUE NOT NULL DEFAULT generate_object_id(),
    name VARCHAR(128) NOT NULL,
    organization_id INTEGER REFERENCES "organization"("id") ON DELETE CASCADE,
    cluster_id INTEGER REFERENCES "cluster"("id") ON DELETE CASCADE,
    resource_type resource_type NOT NULL,
    resource_id INTEGER,
    resource_name VARCHAR(128),
    operation_name VARCHAR(128) NOT NULL,
    info TEXT DEFAULT '{}',
    creator_id INTEGER NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);
