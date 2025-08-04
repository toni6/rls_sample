defmodule RlsSample.Accounts.ScopeTest do
  use RlsSample.DataCase

  alias RlsSample.Accounts
  alias RlsSample.Accounts.{Company, Scope, User}

  describe "for_user/1" do
    test "creates scope for user with preloaded company" do
      {:ok, company} = Accounts.create_company(%{name: "Test Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      user_with_company = user |> Repo.preload(:company)
      scope = Scope.for_user(user_with_company)

      assert %Scope{} = scope
      assert scope.user.id == user.id
      assert scope.company.id == company.id
      assert scope.company.name == "Test Company"
    end

    test "creates scope for user without preloaded company by loading it" do
      {:ok, company} = Accounts.create_company(%{name: "Auto Load Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "autoload@example.com",
          password: "securepassword123",
          role: "admin",
          company_id: company.id
        })

      # User without preloaded company
      scope = Scope.for_user(user)

      assert %Scope{} = scope
      assert scope.user.id == user.id
      assert scope.company.id == company.id
      assert scope.company.name == "Auto Load Company"
      # Verify the user in scope has company preloaded
      assert %Company{} = scope.user.company
    end

    test "returns nil for user with no company" do
      # Create a user but don't assign to any company (edge case)
      user = %User{
        id: Ecto.UUID.generate(),
        email: "orphan@example.com",
        role: "user",
        company_id: nil,
        company: nil
      }

      scope = Scope.for_user(user)
      assert scope == nil
    end

    test "returns nil for nil user" do
      scope = Scope.for_user(nil)
      assert scope == nil
    end

    test "handles user with company set to nil" do
      {:ok, company} = Accounts.create_company(%{name: "Temp Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "temp@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      # Simulate user with company_id but company association nil
      user_without_company = %User{user | company: nil}

      scope = Scope.for_user(user_without_company)

      # When company association is nil, scope should be nil even if company_id exists
      assert scope == nil
    end
  end

  describe "admin?/1" do
    test "returns true for admin user" do
      {:ok, company} = Accounts.create_company(%{name: "Admin Company"})

      {:ok, admin_user} =
        Accounts.register_user(%{
          email: "admin@example.com",
          password: "securepassword123",
          role: "admin",
          company_id: company.id
        })

      scope = Scope.for_user(admin_user |> Repo.preload(:company))

      assert Scope.admin?(scope) == true
    end

    test "returns false for regular user" do
      {:ok, company} = Accounts.create_company(%{name: "User Company"})

      {:ok, regular_user} =
        Accounts.register_user(%{
          email: "user@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      scope = Scope.for_user(regular_user |> Repo.preload(:company))

      assert Scope.admin?(scope) == false
    end

    test "returns false for readonly user" do
      {:ok, company} = Accounts.create_company(%{name: "Readonly Company"})

      {:ok, readonly_user} =
        Accounts.register_user(%{
          email: "readonly@example.com",
          password: "securepassword123",
          role: "readonly",
          company_id: company.id
        })

      scope = Scope.for_user(readonly_user |> Repo.preload(:company))

      assert Scope.admin?(scope) == false
    end

    test "returns false for nil scope" do
      assert Scope.admin?(nil) == false
    end

    test "returns false for scope with nil user" do
      scope = %Scope{user: nil, company: nil}
      assert Scope.admin?(scope) == false
    end

    test "returns false for scope with user having nil role" do
      user = %User{id: Ecto.UUID.generate(), role: nil}
      scope = %Scope{user: user, company: nil}
      assert Scope.admin?(scope) == false
    end
  end

  describe "company_id/1" do
    test "returns company ID for valid scope" do
      {:ok, company} = Accounts.create_company(%{name: "ID Test Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "companyid@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      scope = Scope.for_user(user |> Repo.preload(:company))

      assert Scope.company_id(scope) == company.id
    end

    test "returns nil for scope with nil company" do
      user = %User{id: Ecto.UUID.generate()}
      scope = %Scope{user: user, company: nil}

      assert Scope.company_id(scope) == nil
    end

    test "returns nil for nil scope" do
      assert Scope.company_id(nil) == nil
    end

    test "returns nil for invalid scope structure" do
      assert Scope.company_id(%{invalid: "structure"}) == nil
    end
  end

  describe "user_id/1" do
    test "returns user ID for valid scope" do
      {:ok, company} = Accounts.create_company(%{name: "User ID Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "userid@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      scope = Scope.for_user(user |> Repo.preload(:company))

      assert Scope.user_id(scope) == user.id
    end

    test "returns nil for scope with nil user" do
      {:ok, company} = Accounts.create_company(%{name: "Nil User Company"})
      scope = %Scope{user: nil, company: company}

      assert Scope.user_id(scope) == nil
    end

    test "returns nil for nil scope" do
      assert Scope.user_id(nil) == nil
    end

    test "returns nil for invalid scope structure" do
      assert Scope.user_id(%{invalid: "structure"}) == nil
    end
  end

  describe "scope integration with different user roles" do
    test "creates proper scope for each role type" do
      {:ok, company} = Accounts.create_company(%{name: "Multi Role Company"})

      roles = ["admin", "user", "readonly"]

      for role <- roles do
        {:ok, user} =
          Accounts.register_user(%{
            email: "#{role}@multiroleco.com",
            password: "securepassword123",
            role: role,
            company_id: company.id
          })

        scope = Scope.for_user(user |> Repo.preload(:company))

        assert %Scope{} = scope
        assert scope.user.role == role
        assert scope.company.id == company.id

        # Test admin? function for each role
        expected_admin = role == "admin"
        assert Scope.admin?(scope) == expected_admin
      end
    end
  end

  describe "scope with multiple companies" do
    test "correctly identifies company boundaries" do
      {:ok, company1} = Accounts.create_company(%{name: "Company Alpha"})
      {:ok, company2} = Accounts.create_company(%{name: "Company Beta"})

      {:ok, user1} =
        Accounts.register_user(%{
          email: "alpha@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company1.id
        })

      {:ok, user2} =
        Accounts.register_user(%{
          email: "beta@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company2.id
        })

      scope1 = Scope.for_user(user1 |> Repo.preload(:company))
      scope2 = Scope.for_user(user2 |> Repo.preload(:company))

      # Verify scopes have correct company associations
      assert Scope.company_id(scope1) == company1.id
      assert Scope.company_id(scope2) == company2.id

      # Verify they're different
      assert Scope.company_id(scope1) != Scope.company_id(scope2)

      # Verify user associations
      assert Scope.user_id(scope1) == user1.id
      assert Scope.user_id(scope2) == user2.id
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed user structs gracefully" do
      malformed_user = %{not_a_user: true}

      # Should not crash, should return nil
      assert Scope.for_user(malformed_user) == nil
    end

    test "scope functions handle malformed structs gracefully" do
      malformed_scope = %{not_a_scope: true}

      assert Scope.admin?(malformed_scope) == false
      assert Scope.company_id(malformed_scope) == nil
      assert Scope.user_id(malformed_scope) == nil
    end

    test "handles user with UUID string instead of binary" do
      # This tests robustness against data type variations
      {:ok, company} = Accounts.create_company(%{name: "UUID Test Company"})

      {:ok, user} =
        Accounts.register_user(%{
          email: "uuid@example.com",
          password: "securepassword123",
          role: "user",
          company_id: company.id
        })

      scope = Scope.for_user(user |> Repo.preload(:company))

      # Ensure UUID is properly handled
      assert is_binary(Scope.user_id(scope))
      assert is_binary(Scope.company_id(scope))
    end
  end
end
