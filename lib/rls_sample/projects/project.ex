defmodule RlsSample.Projects.Project do
  @moduledoc """
  Schema and changeset functions for the Project entity.

  Represents projects in the multi-tenant system. Each project belongs
  to a specific company and is isolated by Row Level Security policies
  to ensure users can only access projects from their own company.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "projects" do
    field :name, :string
    field :description, :string

    belongs_to :company, RlsSample.Accounts.Company

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :company_id])
    |> validate_required([:name, :company_id])
    |> validate_length(:name, min: 2, max: 100)
    |> foreign_key_constraint(:company_id)
  end
end
