# RLS Sample App

A Phoenix application demonstrating **Row Level Security (RLS)** with PostgreSQL for secure multi-tenant data isolation.

## 🎯 What This Demonstrates

Enterprise-grade data security using:
- **PostgreSQL Row Level Security (RLS)** policies
- **Phoenix 1.8+ Scopes** for request-level context
- **Multi-tenant data isolation**
- **Database role-based access control**

## 🚀 Quick Start

```bash
# Setup
git clone <repository>
cd rls_sample
mix deps.get
mix ecto.create && mix ecto.migrate
mix run priv/repo/seeds.exs

# Start the application
mix phx.server
```

Visit `http://localhost:4000` to see the app and `http://localhost:4000/rls-demo` for the interactive RLS demonstration.

## 🔒 Test Credentials

```
Acme Corporation:
  admin@acme.com / securepassword123 (admin)
  john@acme.com / securepassword123 (user)

Tech Solutions:
  admin@techsolutions.com / securepassword123 (admin)
  bob@techsolutions.com / securepassword123 (user)
```

## 🧪 Quick Test

```elixir
# Start interactive session
iex -S mix

# Test data isolation
john = RlsSample.Accounts.get_user_by_email("john@acme.com") |> RlsSample.Repo.preload(:company)
bob = RlsSample.Accounts.get_user_by_email("bob@techsolutions.com") |> RlsSample.Repo.preload(:company)

john_scope = RlsSample.Accounts.Scope.for_user(john)
bob_scope = RlsSample.Accounts.Scope.for_user(bob)

# Each user sees only their company's projects
john_projects = RlsSample.Projects.list_projects(john_scope)
bob_projects = RlsSample.Projects.list_projects(bob_scope)

IO.puts "John (#{john.company.name}) sees #{length(john_projects)} projects"
IO.puts "Bob (#{bob.company.name}) sees #{length(bob_projects)} projects"
```

## 📚 Documentation (TODO)

For comprehensive implementation details, architecture explanations, and advanced usage patterns, see this blog article:

[https://todo/blog](https://todo/blog)

## 🛡️ Security Features

- ✅ **Cross-tenant data isolation** - Users only see their company's data
- ✅ **Role-based access control** - Admin/user/readonly permissions
- ✅ **Database-level enforcement** - RLS policies prevent data leakage
- ✅ **Application-level scoping** - Phoenix contexts enforce boundaries

## 🔧 Development

```bash
# Run tests
mix test

# Check code quality
mix credo --strict
```

---

**⚠️ Security Note**: This is a demonstration application. Conduct security reviews before production deployment.
