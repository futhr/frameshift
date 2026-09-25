defmodule FrameshiftPlatform.Catalog.SourceURI do
  @moduledoc "Admits bounded public source locators without fetching them."

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _, _) do
    case Ash.Changeset.get_attribute(changeset, :uri) do
      value when is_binary(value) -> validate_uri(URI.new(value))
      _ -> {:error, field: :uri, message: "requires a public HTTPS source"}
    end
  end

  defp validate_uri({:ok, %URI{scheme: "https", host: host, userinfo: nil, fragment: nil}})
       when is_binary(host) and byte_size(host) > 0, do: :ok

  defp validate_uri(_),
    do: {:error, field: :uri, message: "requires HTTPS without credentials or fragments"}
end
