defmodule FrameshiftPlatformWeb.CatalogProjection do
  @moduledoc "Shared bounded pagination and explicit public Ash attribute projections."

  @spec public_record(module(), struct()) :: map()
  def public_record(resource, record) do
    fields =
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.reject(& &1.sensitive?)
      |> Enum.map(& &1.name)

    Map.take(record, fields)
  end

  @spec offset(term()) :: {:ok, non_neg_integer()} | {:error, :offset}
  def offset(raw) when is_binary(raw) and byte_size(raw) <= 5 do
    case Integer.parse(raw) do
      {value, ""} when value >= 0 and value <= 10_000 -> {:ok, value}
      _ -> {:error, :offset}
    end
  end

  def offset(_), do: {:error, :offset}
end
