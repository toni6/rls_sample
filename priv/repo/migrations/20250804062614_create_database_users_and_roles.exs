defmodule RlsSample.Repo.Migrations.CreateDatabaseUsersAndRoles do
  use Ecto.Migration

  def up do
    # Create application user for runtime operations
    # This user will be used for all application database connections
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rls_app_user') THEN
        CREATE ROLE rls_app_user LOGIN PASSWORD 'secure_app_password_2024';
      END IF;
    END $$
    """

    # Create database roles for RLS policies
    execute "DO $$ BEGIN CREATE ROLE app_admin NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$"

    execute "DO $$ BEGIN CREATE ROLE app_user NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$"

    execute "DO $$ BEGIN CREATE ROLE app_readonly NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$"

    # Grant basic connection privileges to application user
    database_name = repo().config()[:database]
    execute "GRANT CONNECT ON DATABASE #{database_name} TO rls_app_user"
    execute "GRANT USAGE ON SCHEMA public TO rls_app_user"

    # Grant membership in application roles (enables role switching)
    execute "GRANT app_admin TO rls_app_user"
    execute "GRANT app_user TO rls_app_user"
    execute "GRANT app_readonly TO rls_app_user"

    # Grant basic permissions to roles on existing tables (users table from previous migration)
    execute "GRANT USAGE ON SCHEMA public TO app_admin, app_user, app_readonly"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_admin"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON users, users_tokens TO app_user"
    execute "GRANT SELECT ON users TO app_readonly"
    execute "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_admin, app_user"

    # Grant permissions to application user on existing objects
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rls_app_user"
    execute "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rls_app_user"

    # Set up default privileges for future objects created by postgres
    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO rls_app_user"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO rls_app_user"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_admin"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO app_readonly"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO app_admin, app_user"
  end

  def down do
    # Revoke default privileges
    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE USAGE, SELECT ON SEQUENCES FROM app_admin, app_user"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE SELECT ON TABLES FROM app_readonly"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM app_user"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM app_admin"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE USAGE, SELECT ON SEQUENCES FROM rls_app_user"

    execute "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM rls_app_user"

    # Revoke permissions from application user
    execute "REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public FROM rls_app_user"

    execute "REVOKE SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM rls_app_user"

    # Revoke permissions from roles
    execute "REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public FROM app_admin, app_user"
    execute "REVOKE SELECT ON users FROM app_readonly"
    execute "REVOKE SELECT, INSERT, UPDATE, DELETE ON users, users_tokens FROM app_user"
    execute "REVOKE SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM app_admin"
    execute "REVOKE USAGE ON SCHEMA public FROM app_admin, app_user, app_readonly"

    # Revoke role memberships
    execute "REVOKE app_readonly FROM rls_app_user"
    execute "REVOKE app_user FROM rls_app_user"
    execute "REVOKE app_admin FROM rls_app_user"

    # Revoke schema access
    execute "REVOKE USAGE ON SCHEMA public FROM rls_app_user"
    database_name = repo().config()[:database]
    execute "REVOKE CONNECT ON DATABASE #{database_name} FROM rls_app_user"

    # Drop roles (in reverse order to avoid dependency issues)
    execute "DROP ROLE IF EXISTS app_readonly"
    execute "DROP ROLE IF EXISTS app_user"
    execute "DROP ROLE IF EXISTS app_admin"

    # Drop the application user
    execute "DROP ROLE IF EXISTS rls_app_user"
  end
end
