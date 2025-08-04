defmodule RlsSample.Accounts.Company do
  @moduledoc """
  Schema and changeset functions for the Company entity.

  Represents companies in the multi-tenant system. Each company
  is a tenant that isolates its users and projects from other
  companies using Row Level Security policies.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "companies" do
    field :name, :string

    has_many :users, RlsSample.Accounts.User
    has_many :projects, RlsSample.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
    |> unique_constraint(:name)
  end
end
