defmodule RlsSample.Repo.Migrations.SetupMultiTenancyWithRls do
  use Ecto.Migration

  def up do
    # Add fields to users table for multi-tenancy (if they don't exist)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'role') THEN
        ALTER TABLE users ADD COLUMN role VARCHAR(255) NOT NULL DEFAULT 'user';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'company_id') THEN
        ALTER TABLE users ADD COLUMN company_id UUID;
      END IF;
    END $$
    """

    # Create companies table if it doesn't exist
    execute """
    CREATE TABLE IF NOT EXISTS companies (
      id UUID PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
    """

    execute "CREATE UNIQUE INDEX IF NOT EXISTS companies_name_index ON companies (name)"

    # Add foreign key constraint if it doesn't exist
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'users_company_id_fkey') THEN
        ALTER TABLE users ALTER COLUMN company_id SET NOT NULL;
        ALTER TABLE users ADD CONSTRAINT users_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT;
      END IF;
    END $$
    """

    # Create projects table if it doesn't exist
    execute """
    CREATE TABLE IF NOT EXISTS projects (
      id UUID PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      description TEXT,
      company_id UUID NOT NULL,
      inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
    """

    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'projects_company_id_fkey') THEN
        ALTER TABLE projects ADD CONSTRAINT projects_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
      END IF;
    END $$
    """

    execute "CREATE INDEX IF NOT EXISTS projects_company_id_index ON projects (company_id)"

    # Update permissions for new tables (safe to re-run)
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON companies, projects TO app_admin"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON companies, projects TO app_user"
    execute "GRANT SELECT ON companies, projects TO app_readonly"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON companies, projects TO rls_app_user"

    # Create private schema for RLS helper functions
    execute "CREATE SCHEMA IF NOT EXISTS rls_helpers"
    execute "GRANT USAGE ON SCHEMA rls_helpers TO app_admin, app_user, app_readonly"
    execute "GRANT USAGE ON SCHEMA rls_helpers TO rls_app_user"

    # Create helper functions in private schema
    execute """
    CREATE OR REPLACE FUNCTION rls_helpers.current_user_id()
    RETURNS uuid
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    AS $$
      SELECT COALESCE(
        current_setting('app.current_user_id', true)::uuid,
        '00000000-0000-0000-0000-000000000000'::uuid
      );
    $$
    """

    execute """
    CREATE OR REPLACE FUNCTION rls_helpers.current_company_id()
    RETURNS uuid
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    AS $$
      SELECT COALESCE(
        current_setting('app.current_company_id', true)::uuid,
        '00000000-0000-0000-0000-000000000000'::uuid
      );
    $$
    """

    execute """
    CREATE OR REPLACE FUNCTION rls_helpers.is_admin()
    RETURNS boolean
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    AS $$
      SELECT current_setting('app.current_user_role', true) = 'admin';
    $$
    """

    execute """
    CREATE OR REPLACE FUNCTION rls_helpers.current_user_company_id()
    RETURNS uuid
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    AS $$
      SELECT (
        SELECT company_id
        FROM users
        WHERE id = rls_helpers.current_user_id()
      );
    $$
    """

    # Grant execute permissions on helper functions
    execute "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rls_helpers TO app_admin, app_user, app_readonly"
    execute "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rls_helpers TO rls_app_user"

    # Enable RLS on tables
    execute "ALTER TABLE companies ENABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE projects ENABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE users ENABLE ROW LEVEL SECURITY"

    # Companies policies (safe creation)
    execute "DROP POLICY IF EXISTS companies_admin_all ON companies"

    execute """
    CREATE POLICY companies_admin_all ON companies
    FOR ALL TO app_admin
    USING (true)
    WITH CHECK (true)
    """

    execute "DROP POLICY IF EXISTS companies_user_select ON companies"

    execute """
    CREATE POLICY companies_user_select ON companies
    FOR SELECT TO app_user, app_readonly
    USING ((
      SELECT id = rls_helpers.current_user_company_id()
    ))
    """

    # Users policies (safe creation)
    execute "DROP POLICY IF EXISTS users_admin_all ON users"

    execute """
    CREATE POLICY users_admin_all ON users
    FOR ALL TO app_admin
    USING (true)
    WITH CHECK (true)
    """

    execute "DROP POLICY IF EXISTS users_user_select ON users"

    execute """
    CREATE POLICY users_user_select ON users
    FOR SELECT TO app_user, app_readonly
    USING ((
      SELECT company_id = rls_helpers.current_user_company_id()
    ))
    """

    execute "DROP POLICY IF EXISTS users_user_update_self ON users"

    execute """
    CREATE POLICY users_user_update_self ON users
    FOR UPDATE TO app_user
    USING ((
      SELECT id = rls_helpers.current_user_id()
    ))
    WITH CHECK ((
      SELECT id = rls_helpers.current_user_id()
    ))
    """

    # Projects policies (safe creation)
    execute "DROP POLICY IF EXISTS projects_admin_all ON projects"

    execute """
    CREATE POLICY projects_admin_all ON projects
    FOR ALL TO app_admin
    USING (true)
    WITH CHECK (true)
    """

    execute "DROP POLICY IF EXISTS projects_user_company ON projects"

    execute """
    CREATE POLICY projects_user_company ON projects
    FOR ALL TO app_user
    USING ((
      SELECT company_id = rls_helpers.current_user_company_id()
    ))
    WITH CHECK ((
      SELECT company_id = rls_helpers.current_user_company_id()
    ))
    """

    execute "DROP POLICY IF EXISTS projects_readonly_company ON projects"

    execute """
    CREATE POLICY projects_readonly_company ON projects
    FOR SELECT TO app_readonly
    USING ((
      SELECT company_id = rls_helpers.current_user_company_id()
    ))
    """

    # Force RLS for table owners (security best practice)
    execute "ALTER TABLE companies FORCE ROW LEVEL SECURITY"
    execute "ALTER TABLE projects FORCE ROW LEVEL SECURITY"
    execute "ALTER TABLE users FORCE ROW LEVEL SECURITY"
  end

  def down do
    # Disable RLS
    execute "ALTER TABLE users DISABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE projects DISABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE companies DISABLE ROW LEVEL SECURITY"

    # Drop policies
    execute "DROP POLICY IF EXISTS users_user_update_self ON users"
    execute "DROP POLICY IF EXISTS users_user_select ON users"
    execute "DROP POLICY IF EXISTS users_admin_all ON users"
    execute "DROP POLICY IF EXISTS projects_readonly_company ON projects"
    execute "DROP POLICY IF EXISTS projects_user_company ON projects"
    execute "DROP POLICY IF EXISTS projects_admin_all ON projects"
    execute "DROP POLICY IF EXISTS companies_user_select ON companies"
    execute "DROP POLICY IF EXISTS companies_admin_all ON companies"

    # Drop helper functions and schema
    execute "DROP SCHEMA IF EXISTS rls_helpers CASCADE"

    # Remove foreign key constraint before dropping companies table
    execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_company_id_fkey"

    # Drop tables
    drop table(:projects)
    drop table(:companies)

    # Remove added columns from users
    alter table(:users) do
      remove :company_id
      remove :role
    end
  end
end
