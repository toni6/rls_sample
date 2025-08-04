defmodule RlsSample.RLS do
  @moduledoc """
  Provides functions for managing Row Level Security (RLS) context in database operations.

  This module allows setting database session variables that are used by RLS policies
  to control data access based on the current user's scope and role.

  ## Security Features

  - Automatically sets user context for all database operations within a scope
  - Supports role-based access control (admin, user, readonly)
  - Ensures proper isolation between different companies/organizations
  - Provides admin context for system-level operations

  ## Usage

      # For regular user operations
      RLS.with_user_context(scope, fn ->
        Projects.list_projects(scope)
      end)

      # For admin operations that need access to all data
      RLS.with_admin_context(fn ->
        SystemOps.get_system_stats()
      end)
  """

  alias Ecto.Adapters.SQL
  alias RlsSample.{Accounts.Scope, Accounts.User, Repo}

  @doc """
  Executes the given function within a user context, setting appropriate
  database session variables for RLS policies.

  This function sets:
  - app.current_user_id: The ID of the current user
  - app.current_company_id: The ID of the user's company
  - app.current_user_role: The role of the user (admin, user, readonly)

  The database connection role is also switched to match the user's role.

  ## Security Note

  This function ensures that all database operations within the given function
  are executed with the proper user context, enabling RLS policies to restrict
  data access appropriately.
  """
  def with_user_context(%Scope{user: %User{} = user} = scope, fun) when is_function(fun, 0) do
    company_id = Scope.company_id(scope)
    user_role = user.role
    db_role = User.db_role(user)

    Repo.transaction(fn ->
      set_local_parameter("app.current_user_id", user.id)
      set_local_parameter("app.current_company_id", company_id)
      set_local_parameter("app.current_user_role", user_role)
      set_local_role(db_role)

      fun.()
    end)
  end

  def with_user_context(%Scope{user: nil}, _fun) do
    {:error, :no_user_in_scope}
  end

  @doc """
  Executes the given function within an admin context, allowing access to all data.

  This bypasses normal RLS restrictions and should only be used for system-level
  operations that legitimately need access to data across all companies.

  ## Security Note

  Use this function sparingly and only for operations that genuinely require
  system-wide access, such as system maintenance, reporting, or cleanup tasks.
  """
  def with_admin_context(fun) when is_function(fun, 0) do
    Repo.transaction(fn ->
      set_local_parameter("app.current_user_role", "admin")
      set_local_role("app_admin")

      fun.()
    end)
  end

  # Private helper functions

  defp set_local_parameter(param, value) when is_binary(value) or is_struct(value) do
    # PostgreSQL SET LOCAL doesn't support parameterized queries
    # We need to directly interpolate the value, but we control these values so it's safe
    escaped_value = value |> to_string() |> String.replace("'", "''")
    sql = "SET LOCAL #{param} = '#{escaped_value}'"
    SQL.query!(Repo, sql, [])
  end

  defp set_local_parameter(param, _value) do
    raise ArgumentError,
          "Invalid value for parameter #{param}. Must be binary or struct with valid to_string conversion."
  end

  defp set_local_role(role) when role in ["app_admin", "app_user", "app_readonly"] do
    sql = "SET LOCAL ROLE #{role}"
    SQL.query!(Repo, sql, [])
  end

  defp set_local_role(role) do
    raise ArgumentError,
          "Invalid database role: #{role}. Must be one of: app_admin, app_user, app_readonly"
  end
end
