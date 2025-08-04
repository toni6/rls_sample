defmodule RlsSample.Projects do
  @moduledoc """
  The Projects context.

  This context provides functions for managing projects with proper scope-based
  access control using Row Level Security (RLS).

  All functions in this context require a valid scope and will only operate
  on data that the scoped user has access to according to RLS policies.
  """

  import Ecto.Query, warn: false
  alias RlsSample.Accounts.Scope
  alias RlsSample.Projects.Project
  alias RlsSample.{Repo, RLS}

  @doc """
  Returns the list of projects accessible to the given scope.

  Only returns projects belonging to the scope's company due to RLS policies.

  ## Examples

      iex> list_projects(scope)
      [%Project{}, ...]

  """
  def list_projects(%Scope{} = scope) do
    RLS.with_user_context(scope, fn ->
      Repo.all(Project)
    end)
    |> case do
      {:ok, projects} -> projects
      {:error, _reason} -> []
    end
  end

  @doc """
  Gets a single project by ID within the given scope.

  Returns the project if it exists and is accessible to the scope,
  otherwise raises `Ecto.NoResultsError`.

  ## Examples

      iex> get_project!(scope, 123)
      %Project{}

      iex> get_project!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(%Scope{} = scope, id) do
    RLS.with_user_context(scope, fn ->
      Repo.get!(Project, id)
    end)
    |> case do
      {:ok, project} -> project
      {:error, _reason} -> raise Ecto.NoResultsError, queryable: Project
    end
  end

  @doc """
  Gets a single project by ID within the given scope.

  Returns the project if it exists and is accessible to the scope,
  otherwise returns nil.

  ## Examples

      iex> get_project(scope, 123)
      %Project{}

      iex> get_project(scope, 456)
      nil

  """
  def get_project(%Scope{} = scope, id) do
    RLS.with_user_context(scope, fn ->
      Repo.get(Project, id)
    end)
    |> case do
      {:ok, project} -> project
      {:error, _reason} -> nil
    end
  end

  @doc """
  Creates a project within the given scope.

  The project will be automatically associated with the scope's company.

  ## Examples

      iex> create_project(scope, %{name: "My Project"})
      {:ok, %Project{}}

      iex> create_project(scope, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(%Scope{company: company} = scope, attrs) when not is_nil(company) do
    # Normalize attrs to string keys to handle both atom and string keys from tests/forms
    normalized_attrs =
      case attrs do
        %{} when is_map(attrs) ->
          Enum.into(attrs, %{}, fn
            {key, value} when is_atom(key) -> {Atom.to_string(key), value}
            {key, value} -> {key, value}
          end)

        _ ->
          attrs
      end

    attrs_with_company = Map.put(normalized_attrs, "company_id", company.id)

    RLS.with_user_context(scope, fn ->
      %Project{}
      |> Project.changeset(attrs_with_company)
      |> Repo.insert()
    end)
    |> case do
      {:ok, {:ok, project}} ->
        broadcast_project_event(:project_created, project)
        {:ok, project}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:error, _reason} ->
        {:error, %Ecto.Changeset{}}
    end
  end

  def create_project(%Scope{company: nil}, _attrs) do
    {:error, :no_company_in_scope}
  end

  @doc """
  Updates a project within the given scope.

  The project must be accessible to the scope for the update to succeed.

  ## Examples

      iex> update_project(scope, project, %{name: "Updated Name"})
      {:ok, %Project{}}

      iex> update_project(scope, project, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Scope{} = scope, %Project{} = project, attrs) do
    RLS.with_user_context(scope, fn ->
      project
      |> Project.changeset(attrs)
      |> Repo.update()
    end)
    |> case do
      {:ok, {:ok, updated_project}} ->
        broadcast_project_event(:project_updated, updated_project)
        {:ok, updated_project}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:error, _reason} ->
        {:error, %Ecto.Changeset{}}
    end
  end

  @doc """
  Deletes a project within the given scope.

  The project must be accessible to the scope for the deletion to succeed.

  ## Examples

      iex> delete_project(scope, project)
      {:ok, %Project{}}

      iex> delete_project(scope, project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Scope{} = scope, %Project{} = project) do
    RLS.with_user_context(scope, fn ->
      Repo.delete(project)
    end)
    |> case do
      {:ok, {:ok, deleted_project}} ->
        broadcast_project_event(:project_deleted, deleted_project)
        {:ok, deleted_project}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:error, _reason} ->
        {:error, %Ecto.Changeset{}}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  @doc """
  Returns the count of projects accessible to the given scope.

  ## Examples

      iex> count_projects(scope)
      5

  """
  def count_projects(%Scope{} = scope) do
    RLS.with_user_context(scope, fn ->
      Repo.aggregate(Project, :count, :id)
    end)
    |> case do
      {:ok, count} -> count
      {:error, _reason} -> 0
    end
  end

  @doc """
  Subscribes to real-time project updates for the given scope.

  This allows LiveView processes to receive notifications when projects
  are created, updated, or deleted within the scope's company.

  ## Examples

      iex> subscribe_projects(scope)
      :ok

  """
  def subscribe_projects(%Scope{company: company}) when not is_nil(company) do
    Phoenix.PubSub.subscribe(RlsSample.PubSub, "projects:#{company.id}")
  end

  def subscribe_projects(%Scope{company: nil}) do
    {:error, :no_company_in_scope}
  end

  @doc """
  Broadcasts a project event to subscribers.

  This function is used internally to notify subscribers when projects
  are created, updated, or deleted.
  """
  def broadcast_project_event(event, %Project{company_id: company_id} = project) do
    Phoenix.PubSub.broadcast(RlsSample.PubSub, "projects:#{company_id}", {event, project})
  end

  @doc """
  Returns the total count of all projects across all companies.

  This function requires admin context and should only be used for
  system-level operations and reporting.

  ## Examples

      iex> count_all_projects()
      42

  """
  def count_all_projects do
    # This function should only be called within admin context
    Repo.aggregate(Project, :count, :id)
  end

  @doc """
  Returns the count of projects for a specific company.

  This function requires admin context and is used for system-level
  reporting and analytics.

  ## Examples

      iex> count_projects_for_company("company-uuid")
      5

  """
  def count_projects_for_company(company_id) do
    # This function should only be called within admin context
    from(p in Project, where: p.company_id == ^company_id)
    |> Repo.aggregate(:count, :id)
  end
end
