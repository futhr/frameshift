defmodule FrameshiftPlatform.Access.Actor do
  @moduledoc """
  Trusted actor context supplied by an authenticated boundary, never request JSON.
  Constructing this value does not authenticate a caller.
  """

  @enforce_keys [:id, :role]
  defstruct [:id, :role]
  @type t :: %__MODULE__{id: String.t(), role: atom()}

  @spec allowed?(term(), [atom()]) :: boolean()
  def allowed?(%__MODULE__{id: id, role: role}, roles) when is_binary(id) do
    match?({:ok, _}, Ecto.UUID.cast(id)) and role in roles
  end

  def allowed?(_, _), do: false
end
