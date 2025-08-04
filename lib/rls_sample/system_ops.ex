defmodule RlsSample.SystemOps do
  @moduledoc """
  System-level operations that require admin context.

  This module contains functions that need to access data across all companies
  and organizations. These operations bypass normal RLS restrictions and should
  only be used for legitimate system administration tasks.

  All functions in this module use admin context and should be called only
  by system administrators or automated system processes.
  """

  import Ecto.Query, warn: false
  alias RlsSample.{Repo, RLS}
  alias RlsSample.Accounts.{Company, User}
  alias RlsSample.Projects.Project

  @doc """
  Returns system statistics across all organizations.

  Returns a map containing various system-wide metrics.

  ## Examples

      iex> get_system_stats()
      {:ok, %{
        total_companies: 15,
        total_users: 150,
        total_projects: 1250,
        users_per_company: 10.0
      }}

  """
  def get_system_stats do
    RLS.with_admin_context(fn ->
      company_count = Repo.aggregate(Company, :count, :id)
      user_count = Repo.aggregate(User, :count, :id)
      project_count = Repo.aggregate(Project, :count, :id)

      users_per_company =
        if company_count > 0 do
          user_count / company_count
        else
          0.0
        end

      %{
        total_companies: company_count,
        total_users: user_count,
        total_projects: project_count,
        users_per_company: Float.round(users_per_company, 2)
      }
    end)
  end
end
