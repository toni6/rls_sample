defmodule RlsSampleWeb.RlsDemoLive.Index do
  use RlsSampleWeb, :live_view

  alias RlsSample.{Accounts, Projects, RLS}
  alias RlsSample.Accounts.Scope

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates if user has a company
      if socket.assigns.current_scope && socket.assigns.current_scope.company do
        Projects.subscribe_projects(socket.assigns.current_scope)
      end
    end

    socket =
      socket
      |> assign(:page_title, "RLS Demo")
      |> assign(:demo_mode, :user_context)
      |> assign(
        :selected_user_id,
        socket.assigns.current_scope && socket.assigns.current_scope.user &&
          socket.assigns.current_scope.user.id
      )
      |> assign(:admin_results, nil)
      |> assign(:cross_company_test_results, nil)
      |> load_demo_data()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_demo_mode", %{"mode" => mode}, socket) do
    demo_mode = String.to_existing_atom(mode)

    socket =
      socket
      |> assign(:demo_mode, demo_mode)
      |> load_demo_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_user_context", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id) |> RlsSample.Repo.preload(:company)
    test_scope = Scope.for_user(user)

    # Load projects for the selected user
    projects = Projects.list_projects(test_scope)

    socket =
      socket
      |> assign(:selected_user_id, user_id)
      |> assign(:test_scope, test_scope)
      |> assign(:test_user, user)
      |> assign(:test_projects, projects)
      |> assign(:test_project_count, Projects.count_projects(test_scope))

    {:noreply, socket}
  rescue
    Ecto.NoResultsError ->
      socket = put_flash(socket, :error, "User not found")
      {:noreply, socket}
  end

  @impl true
  def handle_event("run_admin_test", _params, socket) do
    # Demonstrate admin context functionality
    case RLS.with_admin_context(fn ->
           %{
             total_companies: Accounts.list_companies() |> length(),
             total_users: length(Accounts.get_all_users()),
             total_projects: Projects.count_all_projects(),
             companies_with_projects: get_companies_with_project_counts()
           }
         end) do
      {:ok, results} ->
        {:noreply, assign(socket, :admin_results, results)}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Admin test failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("run_cross_company_test", _params, socket) do
    # Test that users cannot access other companies' data
    test_results = run_cross_company_security_test()
    {:noreply, assign(socket, :cross_company_test_results, test_results)}
  end

  @impl true
  def handle_event("create_test_project", %{"project" => project_params}, socket) do
    case Projects.create_project(socket.assigns.current_scope, project_params) do
      {:ok, project} ->
        # Broadcast the event for real-time updates
        Projects.broadcast_project_event(:project_created, project)

        socket =
          socket
          |> put_flash(:info, "Project '#{project.name}' created successfully!")
          |> load_demo_data()

        {:noreply, socket}

      {:error, %Ecto.Changeset{}} ->
        socket = put_flash(socket, :error, "Failed to create project. Please check your input.")
        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to create project: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_project", %{"id" => project_id}, socket) do
    project = Projects.get_project!(socket.assigns.current_scope, project_id)

    case Projects.delete_project(socket.assigns.current_scope, project) do
      {:ok, deleted_project} ->
        # Broadcast the event for real-time updates
        Projects.broadcast_project_event(:project_deleted, deleted_project)

        socket =
          socket
          |> put_flash(:info, "Project '#{deleted_project.name}' deleted successfully!")
          |> load_demo_data()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to delete project: #{inspect(reason)}")
        {:noreply, socket}
    end
  rescue
    Ecto.NoResultsError ->
      socket = put_flash(socket, :error, "Project not found or access denied")
      {:noreply, socket}
  end

  @impl true
  def handle_info({:project_created, _project}, socket) do
    {:noreply, load_demo_data(socket)}
  end

  @impl true
  def handle_info({:project_updated, _project}, socket) do
    {:noreply, load_demo_data(socket)}
  end

  @impl true
  def handle_info({:project_deleted, _project}, socket) do
    {:noreply, load_demo_data(socket)}
  end

  # Private functions

  defp load_demo_data(socket) do
    current_scope = socket.assigns.current_scope

    if current_scope && current_scope.user do
      projects = Projects.list_projects(current_scope)
      project_count = Projects.count_projects(current_scope)
      all_users = get_demo_users()

      socket
      |> assign(:projects, projects)
      |> assign(:project_count, project_count)
      |> assign(:all_users, all_users)
      |> assign(:current_company, current_scope.company)
    else
      socket
      |> assign(:projects, [])
      |> assign(:project_count, 0)
      |> assign(:all_users, [])
      |> assign(:current_company, nil)
    end
  end

  defp get_demo_users do
    # Get users from different companies for demonstration
    demo_emails = [
      "admin@acme.com",
      "john@acme.com",
      "jane@acme.com",
      "readonly@acme.com",
      "admin@techsolutions.com",
      "bob@techsolutions.com",
      "founder@startup.com"
    ]

    demo_emails
    |> Enum.map(&Accounts.get_user_by_email/1)
    |> Enum.filter(& &1)
    |> Enum.map(&RlsSample.Repo.preload(&1, :company))
  end

  defp get_companies_with_project_counts do
    Accounts.list_companies()
    |> Enum.map(fn company ->
      # This works because we're in admin context
      project_count = Projects.count_projects_for_company(company.id)
      %{company: company, project_count: project_count}
    end)
  end

  defp run_cross_company_security_test do
    users = get_demo_users()
    Enum.map(users, &test_user_security/1)
  end

  defp test_user_security(user) do
    scope = Scope.for_user(user)
    user_projects = Projects.list_projects(scope)
    grouped_users = get_other_company_users(user)
    access_test_results = test_cross_company_access(scope, user, grouped_users)
    security_breaches = calculate_security_breaches(user, access_test_results)

    # Calculate total accessible projects for admin reporting
    total_accessible =
      if user.role == "admin" do
        same_company_accessible =
          access_test_results
          |> Map.get(:same_company, [])
          |> Enum.map(& &1.accessible_projects)
          |> Enum.sum()

        cross_company_accessible =
          access_test_results
          |> Map.get(:cross_company, [])
          |> Enum.map(& &1.accessible_projects)
          |> Enum.sum()

        length(user_projects) + same_company_accessible + cross_company_accessible
      else
        length(user_projects)
      end

    %{
      user: user,
      company: user.company.name,
      own_projects: length(user_projects),
      total_accessible_projects: total_accessible,
      access_test_results: access_test_results,
      security_breaches: security_breaches,
      is_admin: user.role == "admin"
    }
  end

  defp get_other_company_users(user) do
    get_demo_users()
    |> Enum.reject(&(&1.id == user.id))
    |> Enum.group_by(&(&1.company_id == user.company_id))
  end

  defp test_cross_company_access(scope, user, grouped_users) do
    same_company_users = Map.get(grouped_users, true, [])
    other_company_users = Map.get(grouped_users, false, [])

    # Test access to same company projects (should be accessible)
    same_company_results = test_company_access(scope, user, same_company_users, :same_company)

    # Test access to other company projects (should NOT be accessible for regular users)
    cross_company_results = test_company_access(scope, user, other_company_users, :cross_company)

    %{
      same_company: same_company_results,
      cross_company: cross_company_results
    }
  end

  defp test_company_access(scope, user, users_list, access_type) do
    Enum.map(users_list, fn other_user ->
      other_scope = Scope.for_user(other_user)
      other_projects = Projects.list_projects(other_scope)

      # Filter projects to only include those that actually belong to the other user's company
      # This prevents false breaches when admin users return projects from all companies
      actual_other_company_projects =
        if access_type == :cross_company do
          Enum.filter(other_projects, &(&1.company_id == other_user.company_id))
        else
          other_projects
        end

      accessible_projects = count_accessible_projects(scope, user, actual_other_company_projects)

      %{
        target_company: other_user.company.name,
        target_projects: length(actual_other_company_projects),
        accessible_projects: accessible_projects,
        access_type: access_type
      }
    end)
  end

  defp count_accessible_projects(scope, user, other_projects) do
    other_projects
    |> Enum.map(&check_project_accessibility(scope, user, &1))
    |> Enum.sum()
  end

  defp check_project_accessibility(scope, _user, other_project) do
    case Projects.get_project(scope, other_project.id) do
      nil -> 0
      # Can access this project
      _accessed_project -> 1
    end
  end

  defp calculate_security_breaches(user, test_results) do
    cross_company_results = Map.get(test_results, :cross_company, [])

    if user.role == "admin" do
      # For admins, cross-company access is expected/legitimate, so no breaches
      0
    else
      # For regular users, any cross-company access is a security breach
      Enum.sum(Enum.map(cross_company_results, & &1.accessible_projects))
    end
  end

  # Helper function to get company name safely
  defp company_name(%{company: %{name: name}}), do: name
  defp company_name(_), do: "No Company"

  # Helper function to get user role safely
  defp user_role(%{role: role}), do: String.upcase(role)
  defp user_role(_), do: "UNKNOWN"
end
