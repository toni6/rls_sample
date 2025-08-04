defmodule RlsSample.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `RlsSample.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.
  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias RlsSample.Accounts.{Company, User}

  defstruct user: nil, company: nil

  @doc """
  Creates a scope for the given user with their company loaded.

  Returns nil if no user is given.
  """
  def for_user(%User{company: %Company{} = company} = user) do
    %__MODULE__{user: user, company: company}
  end

  def for_user(%User{} = user) do
    # For users without preloaded company, we'll load it
    case RlsSample.Repo.preload(user, :company) do
      %User{company: %Company{} = company} = loaded_user ->
        %__MODULE__{user: loaded_user, company: company}

      %User{company: nil} ->
        # User has no company - this shouldn't happen in normal flow
        nil
    end
  end

  def for_user(nil), do: nil

  # Catch-all for any non-User input
  def for_user(_), do: nil

  @doc """
  Returns true if the scope represents an admin user.
  """
  def admin?(%__MODULE__{user: %User{role: "admin"}}), do: true
  def admin?(_), do: false

  @doc """
  Returns the company ID from the scope.
  """
  def company_id(%__MODULE__{company: %Company{id: id}}), do: id
  def company_id(_), do: nil

  @doc """
  Returns the user ID from the scope.
  """
  def user_id(%__MODULE__{user: %User{id: id}}), do: id
  def user_id(_), do: nil
end
