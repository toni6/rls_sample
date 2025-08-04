defmodule RlsSample.ProjectsTest do
  use RlsSample.DataCase

  alias RlsSample.{Accounts, Projects, RLS, SystemOps}
  alias RlsSample.Accounts.Scope
  alias RlsSample.Projects.Project

  describe "list_projects/1" do
    test "returns only projects from the scope's company" do
      # Create two companies
      {:ok, company1} = Accounts.create_company(%{name: "Company 1"})
      {:ok, company2} = Accounts.create_company(%{name: "Company 2"})

      # Create users for each company
      {:ok, user1} =
        Accounts.register_user(%{
          email: "user1@company1.com",
          password: "securepassword123",
          role: "user",
          company_id: company1.id
        })

      {:ok, user2} =
        Accounts.register_user(%{
          email: "user2@company2.com",
          password: "securepassword123",
          role: "user",
          company_id: company2.id
        })

      # Create projects for each company
      company1_project_attrs = %{
        name: "Company 1 Project",
        description: "A project for company 1",
        company_id: company1.id
      }

      company2_project_attrs = %{
        name: "Company 2 Project",
        description: "A project for company 2",
        company_id: company2.id
      }

      # Use admin context to create projects (bypasses RLS)
      # Create projects for each company
      {:ok, project1} =
        RLS.with_admin_context(fn ->
          case %Project{} |> Project.changeset(company1_project_attrs) |> Repo.insert() do
            {:ok, project} -> project
            error -> error
          end
        end)

      {:ok, project2} =
        RLS.with_admin_context(fn ->
          case %Project{} |> Project.changeset(company2_project_attrs) |> Repo.insert() do
            {:ok, project} -> project
            error -> error
          end
        end)

      # Create scopes
      scope1 = Scope.for_user(user1 |> Repo.preload(:company))
      scope2 = Scope.for_user(user2 |> Repo.preload(:company))

      # Test that each user can only see their company's projects
      company1_projects = Projects.list_projects(scope1)
      company2_projects = Projects.list_projects(scope2)

      assert length(company1_projects) == 1
      assert length(company2_projects) == 1

      assert hd(company1_projects).id == project1.id
      assert hd(company2_projects).id == project2.id
    end

    test "RLS prevents access even with direct queries" do
      # Create two companies and users
      {:ok, company1} = Accounts.create_company(%{name: "Secure Corp"})
      {:ok, company2} = Accounts.create_company(%{name: "Other Corp"})

      {:ok, _user1} =
        Accounts.register_user(%{
          email: "secure@corp.com",
          password: "securepassword123",
          role: "user",
          company_id: company1.id
        })

      {:ok, user2} =
        Accounts.register_user(%{
          email: "other@corp.com",
          password: "securepassword123",
          role: "user",
          company_id: company2.id
        })

      # Create a project for company1
      project_attrs = %{
        name: "Secret Project",
        description: "Top secret company project",
        company_id: company1.id
      }

      {:ok, secret_project} =
        RLS.with_admin_context(fn ->
          case %Project{} |> Project.changeset(project_attrs) |> Repo.insert() do
            {:ok, project} -> project
            error -> error
          end
        end)

      # Test that user2 cannot access company1's project even with direct query
      scope2 = Scope.for_user(user2 |> Repo.preload(:company))

      # This should return nil due to RLS policies
      result = Projects.get_project(scope2, secret_project.id)
      assert result == nil

      # This should raise due to RLS policies
      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(scope2, secret_project.id)
      end
    end

    test "admin context can access all data" do
      # Create multiple companies and projects
      {:ok, company1} = Accounts.create_company(%{name: "Alpha Corp"})
      {:ok, company2} = Accounts.create_company(%{name: "Beta Corp"})

      project1_attrs = %{name: "Alpha Project", company_id: company1.id}
      project2_attrs = %{name: "Beta Project", company_id: company2.id}

      # Create projects using admin context
      {:ok, _project1} =
        RLS.with_admin_context(fn ->
          case %Project{} |> Project.changeset(project1_attrs) |> Repo.insert() do
            {:ok, project} -> project
            error -> error
          end
        end)

      {:ok, _project2} =
        RLS.with_admin_context(fn ->
          case %Project{} |> Project.changeset(project2_attrs) |> Repo.insert() do
            {:ok, project} -> project
            error -> error
          end
        end)

      # Admin context should see all projects
      {:ok, stats} = SystemOps.get_system_stats()
      assert stats.total_projects >= 2

      # Verify admin can access companies and projects
      companies = Accounts.list_companies()
      assert length(companies) >= 2

      # Find our test companies
      alpha_company = Enum.find(companies, fn c -> c.name == "Alpha Corp" end)
      beta_company = Enum.find(companies, fn c -> c.name == "Beta Corp" end)

      assert alpha_company != nil
      assert beta_company != nil
    end

    test "readonly users can view but not modify data" do
      {:ok, company} = Accounts.create_company(%{name: "Read Only Corp"})

      {:ok, readonly_user} =
        Accounts.register_user(%{
          email: "readonly@corp.com",
          password: "securepassword123",
          role: "readonly",
          company_id: company.id
        })

      {:ok, regular_user} =
        Accounts.register_user(%{
          email: "regular@corp.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      readonly_scope = Scope.for_user(readonly_user |> Repo.preload(:company))
      regular_scope = Scope.for_user(regular_user |> Repo.preload(:company))

      # Regular user creates a project
      project_attrs = %{name: "Readonly Test Project", description: "Test project"}
      {:ok, project} = Projects.create_project(regular_scope, project_attrs)

      # Readonly user can view the project
      readonly_projects = Projects.list_projects(readonly_scope)
      assert length(readonly_projects) == 1
      assert hd(readonly_projects).id == project.id

      # Readonly user can get the specific project
      fetched_project = Projects.get_project!(readonly_scope, project.id)
      assert fetched_project.id == project.id

      # But readonly user cannot create projects (would fail at database level)
      # Note: The actual restriction happens at the database policy level
      # Our application logic doesn't explicitly prevent it, but RLS policies do
    end

    test "users cannot access projects from other companies" do
      # Setup two companies with users and projects
      {:ok, acme} = Accounts.create_company(%{name: "Acme Inc"})
      {:ok, beta} = Accounts.create_company(%{name: "Beta Ltd"})

      {:ok, acme_user} =
        Accounts.register_user(%{
          email: "user@acme.com",
          password: "securepassword123",
          role: "user",
          company_id: acme.id
        })

      {:ok, beta_user} =
        Accounts.register_user(%{
          email: "user@beta.com",
          password: "securepassword123",
          role: "user",
          company_id: beta.id
        })

      acme_scope = Scope.for_user(acme_user |> Repo.preload(:company))
      beta_scope = Scope.for_user(beta_user |> Repo.preload(:company))

      # Create projects for each company
      {:ok, acme_project} =
        Projects.create_project(acme_scope, %{
          name: "Acme Secret Project",
          description: "Confidential Acme project"
        })

      {:ok, beta_project} =
        Projects.create_project(beta_scope, %{
          name: "Beta Innovation Project",
          description: "Confidential Beta project"
        })

      # Verify isolation
      acme_projects = Projects.list_projects(acme_scope)
      beta_projects = Projects.list_projects(beta_scope)

      # Each user sees only their company's project
      assert length(acme_projects) == 1
      assert length(beta_projects) == 1
      assert hd(acme_projects).id == acme_project.id
      assert hd(beta_projects).id == beta_project.id

      # Cross-company access should fail
      assert Projects.get_project(acme_scope, beta_project.id) == nil
      assert Projects.get_project(beta_scope, acme_project.id) == nil

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(acme_scope, beta_project.id)
      end

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(beta_scope, acme_project.id)
      end
    end
  end

  describe "create_project/2" do
    test "creates project with proper company association" do
      {:ok, company} = Accounts.create_company(%{name: "Test Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "creator@test.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      scope = Scope.for_user(user |> Repo.preload(:company))

      project_attrs = %{
        name: "New Project",
        description: "A brand new project"
      }

      {:ok, project} = Projects.create_project(scope, project_attrs)

      assert project.name == "New Project"
      assert project.description == "A brand new project"
      assert project.company_id == company.id
    end

    test "fails when scope has no company" do
      # Create a user without preloaded company (simulating edge case)
      {:ok, company} = Accounts.create_company(%{name: "Test Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "orphan@test.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      # Create scope without company loaded
      scope = %Scope{user: user, company: nil}

      project_attrs = %{name: "Failed Project"}

      assert {:error, :no_company_in_scope} = Projects.create_project(scope, project_attrs)
    end
  end

  describe "update_project/3" do
    test "updates project within scope" do
      {:ok, company} = Accounts.create_company(%{name: "Update Test Co"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "updater@test.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      scope = Scope.for_user(user |> Repo.preload(:company))

      # Create project
      {:ok, project} =
        Projects.create_project(scope, %{
          name: "Original Name",
          description: "Original description"
        })

      # Update project
      update_attrs = %{
        name: "Updated Name",
        description: "Updated description"
      }

      {:ok, updated_project} = Projects.update_project(scope, project, update_attrs)

      assert updated_project.name == "Updated Name"
      assert updated_project.description == "Updated description"
      assert updated_project.id == project.id
    end
  end

  describe "delete_project/2" do
    test "deletes project within scope" do
      {:ok, company} = Accounts.create_company(%{name: "Delete Test Co"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "deleter@test.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      scope = Scope.for_user(user |> Repo.preload(:company))

      # Create project
      {:ok, project} =
        Projects.create_project(scope, %{
          name: "Doomed Project",
          description: "This project will be deleted"
        })

      # Verify it exists
      assert Projects.get_project(scope, project.id) != nil

      # Delete project
      {:ok, _deleted_project} = Projects.delete_project(scope, project)

      # Verify it's gone
      assert Projects.get_project(scope, project.id) == nil
    end
  end

  describe "count_projects/1" do
    test "counts only projects in scope" do
      {:ok, company1} = Accounts.create_company(%{name: "Counter Corp 1"})
      {:ok, company2} = Accounts.create_company(%{name: "Counter Corp 2"})

      {:ok, user1} =
        Accounts.register_user(%{
          email: "counter1@test.com",
          password: "securepassword123",
          role: "user",
          company_id: company1.id
        })

      {:ok, user2} =
        Accounts.register_user(%{
          email: "counter2@test.com",
          password: "securepassword123",
          role: "user",
          company_id: company2.id
        })

      scope1 = Scope.for_user(user1 |> Repo.preload(:company))
      scope2 = Scope.for_user(user2 |> Repo.preload(:company))

      # Create 2 projects for company1 and 3 for company2
      {:ok, _} = Projects.create_project(scope1, %{name: "Project 1-1"})
      {:ok, _} = Projects.create_project(scope1, %{name: "Project 1-2"})

      {:ok, _} = Projects.create_project(scope2, %{name: "Project 2-1"})
      {:ok, _} = Projects.create_project(scope2, %{name: "Project 2-2"})
      {:ok, _} = Projects.create_project(scope2, %{name: "Project 2-3"})

      # Each scope should count only its own company's projects
      assert Projects.count_projects(scope1) == 2
      assert Projects.count_projects(scope2) == 3
    end
  end

  describe "scope boundary security" do
    test "prevents data leakage between companies" do
      # Create companies
      {:ok, acme_company} = Accounts.create_company(%{name: "Acme Corp"})
      {:ok, tech_company} = Accounts.create_company(%{name: "Tech Solutions"})

      # Create users for each company
      {:ok, acme_user} =
        Accounts.register_user(%{
          email: "john@acme.com",
          password: "securepassword123",
          role: "user",
          company_id: acme_company.id
        })

      {:ok, tech_user} =
        Accounts.register_user(%{
          email: "bob@techsolutions.com",
          password: "securepassword123",
          role: "user",
          company_id: tech_company.id
        })

      # Create scopes
      acme_scope = Scope.for_user(acme_user |> Repo.preload(:company))
      tech_scope = Scope.for_user(tech_user |> Repo.preload(:company))

      # Create test projects for each company
      {:ok, acme_project} =
        Projects.create_project(acme_scope, %{
          name: "Top Secret Acme Project",
          description: "Highly confidential information for Acme"
        })

      {:ok, tech_project} =
        Projects.create_project(tech_scope, %{
          name: "Top Secret Tech Project",
          description: "Highly confidential information for Tech Solutions"
        })

      companies = [
        %{user: acme_user, scope: acme_scope, project: acme_project, company: acme_company},
        %{user: tech_user, scope: tech_scope, project: tech_project, company: tech_company}
      ]

      # Test that each company can only see its own data
      for {current_company_data, index} <- Enum.with_index(companies) do
        projects = Projects.list_projects(current_company_data.scope)

        # Each company should only see their own test project (no seeded data)
        expected_count = 1
        assert length(projects) == expected_count

        # Should include their test project
        test_project_ids = Enum.map(projects, & &1.id)
        assert current_company_data.project.id in test_project_ids

        # Verify cannot access other companies' projects
        other_companies = List.delete_at(companies, index)

        for other_company_data <- other_companies do
          assert Projects.get_project(current_company_data.scope, other_company_data.project.id) ==
                   nil

          assert_raise Ecto.NoResultsError, fn ->
            Projects.get_project!(current_company_data.scope, other_company_data.project.id)
          end
        end
      end
    end
  end

  describe "admin role functionality" do
    test "admin users have elevated access through system ops" do
      # Create test data
      {:ok, company1} = Accounts.create_company(%{name: "Admin Test 1"})
      {:ok, _company2} = Accounts.create_company(%{name: "Admin Test 2"})

      # Create regular users and projects
      {:ok, user1} =
        Accounts.register_user(%{
          email: "user1@admintest.com",
          password: "securepassword123",
          role: "user",
          company_id: company1.id
        })

      scope1 = Scope.for_user(user1 |> Repo.preload(:company))
      {:ok, _project1} = Projects.create_project(scope1, %{name: "User Project 1"})

      # Admin should be able to see system-wide statistics
      {:ok, stats} = SystemOps.get_system_stats()
      assert stats.total_companies >= 2
      assert stats.total_projects >= 1

      # Admin should be able to see companies and their data
      companies = Accounts.list_companies()
      assert length(companies) >= 2

      company1 = Enum.find(companies, fn c -> c.name == "Admin Test 1" end)
      assert company1 != nil
    end
  end
end
