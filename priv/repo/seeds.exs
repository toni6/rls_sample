# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     RlsSample.Repo.insert!(%RlsSample.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias RlsSample.{Accounts, SystemOps, RLS}
alias RlsSample.Accounts.User
alias RlsSample.Projects.Project

import Ecto.Query

# Use admin context to create seed data (bypasses RLS)
{:ok, _} =
  RLS.with_admin_context(fn ->
    # Create companies (handle existing data)
    acme_corp =
      case Accounts.get_company_by_name("Acme Corporation") do
        nil ->
          {:ok, company} = Accounts.create_company(%{name: "Acme Corporation"})
          company

        existing ->
          existing
      end

    tech_solutions =
      case Accounts.get_company_by_name("Tech Solutions Ltd") do
        nil ->
          {:ok, company} = Accounts.create_company(%{name: "Tech Solutions Ltd"})
          company

        existing ->
          existing
      end

    startup_inc =
      case Accounts.get_company_by_name("Startup Inc") do
        nil ->
          {:ok, company} = Accounts.create_company(%{name: "Startup Inc"})
          company

        existing ->
          existing
      end

    IO.puts("Companies ready:")
    IO.puts("- #{acme_corp.name} (#{acme_corp.id})")
    IO.puts("- #{tech_solutions.name} (#{tech_solutions.id})")
    IO.puts("- #{startup_inc.name} (#{startup_inc.id})")

    # Create users for Acme Corporation (handle existing)
    unless Accounts.get_user_by_email("admin@acme.com") do
      {:ok, _admin_acme} =
        Accounts.register_user(%{
          email: "admin@acme.com",
          password: "securepassword123",
          role: "admin",
          company_id: acme_corp.id
        })
    end

    unless Accounts.get_user_by_email("john@acme.com") do
      {:ok, _user_acme1} =
        Accounts.register_user(%{
          email: "john@acme.com",
          password: "securepassword123",
          role: "user",
          company_id: acme_corp.id
        })
    end

    unless Accounts.get_user_by_email("jane@acme.com") do
      {:ok, _user_acme2} =
        Accounts.register_user(%{
          email: "jane@acme.com",
          password: "securepassword123",
          role: "user",
          company_id: acme_corp.id
        })
    end

    unless Accounts.get_user_by_email("readonly@acme.com") do
      {:ok, _readonly_acme} =
        Accounts.register_user(%{
          email: "readonly@acme.com",
          password: "securepassword123",
          role: "readonly",
          company_id: acme_corp.id
        })
    end

    # Create users for Tech Solutions
    unless Accounts.get_user_by_email("admin@techsolutions.com") do
      {:ok, _admin_tech} =
        Accounts.register_user(%{
          email: "admin@techsolutions.com",
          password: "securepassword123",
          role: "admin",
          company_id: tech_solutions.id
        })
    end

    unless Accounts.get_user_by_email("bob@techsolutions.com") do
      {:ok, _user_tech} =
        Accounts.register_user(%{
          email: "bob@techsolutions.com",
          password: "securepassword123",
          role: "user",
          company_id: tech_solutions.id
        })
    end

    # Create users for Startup Inc
    unless Accounts.get_user_by_email("founder@startup.com") do
      {:ok, _user_startup} =
        Accounts.register_user(%{
          email: "founder@startup.com",
          password: "securepassword123",
          role: "user",
          company_id: startup_inc.id
        })
    end

    IO.puts("\nUsers ready:")
    IO.puts("- admin@acme.com (admin, Acme Corporation)")
    IO.puts("- john@acme.com (user, Acme Corporation)")
    IO.puts("- jane@acme.com (user, Acme Corporation)")
    IO.puts("- readonly@acme.com (readonly, Acme Corporation)")
    IO.puts("- admin@techsolutions.com (admin, Tech Solutions)")
    IO.puts("- bob@techsolutions.com (user, Tech Solutions)")
    IO.puts("- founder@startup.com (user, Startup Inc)")

    # Create projects for each company (handle existing)
    acme_projects = [
      %{
        name: "Website Redesign",
        description: "Complete overhaul of company website",
        company_id: acme_corp.id
      },
      %{
        name: "Mobile App",
        description: "New mobile application for customers",
        company_id: acme_corp.id
      },
      %{
        name: "Database Migration",
        description: "Migrate legacy database to PostgreSQL",
        company_id: acme_corp.id
      }
    ]

    tech_projects = [
      %{
        name: "Client Portal",
        description: "Customer self-service portal",
        company_id: tech_solutions.id
      },
      %{
        name: "API Development",
        description: "REST API for third-party integrations",
        company_id: tech_solutions.id
      }
    ]

    startup_projects = [
      %{
        name: "MVP Development",
        description: "Minimum viable product for launch",
        company_id: startup_inc.id
      }
    ]

    # Insert projects only if they don't exist
    Enum.each(acme_projects, fn project_attrs ->
      existing =
        from(p in Project,
          where: p.name == ^project_attrs.name and p.company_id == ^project_attrs.company_id
        )
        |> RlsSample.Repo.one()

      unless existing do
        %Project{}
        |> Project.changeset(project_attrs)
        |> RlsSample.Repo.insert!()
      end
    end)

    Enum.each(tech_projects, fn project_attrs ->
      existing =
        from(p in Project,
          where: p.name == ^project_attrs.name and p.company_id == ^project_attrs.company_id
        )
        |> RlsSample.Repo.one()

      unless existing do
        %Project{}
        |> Project.changeset(project_attrs)
        |> RlsSample.Repo.insert!()
      end
    end)

    Enum.each(startup_projects, fn project_attrs ->
      existing =
        from(p in Project,
          where: p.name == ^project_attrs.name and p.company_id == ^project_attrs.company_id
        )
        |> RlsSample.Repo.one()

      unless existing do
        %Project{}
        |> Project.changeset(project_attrs)
        |> RlsSample.Repo.insert!()
      end
    end)

    current_acme_count =
      from(p in Project, where: p.company_id == ^acme_corp.id)
      |> RlsSample.Repo.aggregate(:count, :id)

    current_tech_count =
      from(p in Project, where: p.company_id == ^tech_solutions.id)
      |> RlsSample.Repo.aggregate(:count, :id)

    current_startup_count =
      from(p in Project, where: p.company_id == ^startup_inc.id)
      |> RlsSample.Repo.aggregate(:count, :id)

    IO.puts("\nProjects ready:")
    IO.puts("- Acme Corporation: #{current_acme_count} projects")
    IO.puts("- Tech Solutions: #{current_tech_count} projects")
    IO.puts("- Startup Inc: #{current_startup_count} projects")

    # Confirm users by setting confirmed_at
    from(u in User)
    |> RlsSample.Repo.update_all(set: [confirmed_at: DateTime.utc_now()])

    IO.puts("\nAll users confirmed")

    :ok
  end)

# Display system statistics
{:ok, stats} = SystemOps.get_system_stats()

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("SEED DATA SUMMARY")
IO.puts(String.duplicate("=", 50))
IO.puts("Total Companies: #{stats.total_companies}")
IO.puts("Total Users: #{stats.total_users}")
IO.puts("Total Projects: #{stats.total_projects}")
IO.puts("Average Users per Company: #{stats.users_per_company}")

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("TEST CREDENTIALS")
IO.puts(String.duplicate("=", 50))
IO.puts("Acme Corporation:")
IO.puts("  admin@acme.com / securepassword123 (admin)")
IO.puts("  john@acme.com / securepassword123 (user)")
IO.puts("  jane@acme.com / securepassword123 (user)")
IO.puts("  readonly@acme.com / securepassword123 (readonly)")
IO.puts("")
IO.puts("Tech Solutions:")
IO.puts("  admin@techsolutions.com / securepassword123 (admin)")
IO.puts("  bob@techsolutions.com / securepassword123 (user)")
IO.puts("")
IO.puts("Startup Inc:")
IO.puts("  founder@startup.com / securepassword123 (user)")

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("RLS TESTING NOTES")
IO.puts(String.duplicate("=", 50))
IO.puts("1. Users can only see projects from their own company")
IO.puts("2. Admin users have full access to all data")
IO.puts("3. Readonly users can view but not modify data")
IO.puts("4. Regular users can create/update/delete within their company")
IO.puts("5. RLS policies prevent cross-company data access")

IO.puts("\nSeeding complete! 🌱")
