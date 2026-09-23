defmodule Frameshift.Transport.SystemResolver do
  @moduledoc """
  Resolves all address families for a frame's advertised HTTPS authority.

  The transport admits every returned address against local-network policy
  before connecting, rather than trusting a hostname or one DNS answer.
  """

  @spec resolve(String.t(), term()) :: {:ok, [:inet.ip_address()]} | {:error, atom()}
  def resolve(host, _config) when is_binary(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} -> {:ok, [address]}
      {:error, :einval} -> resolve_name(host)
    end
  end

  def resolve(_host, _config), do: {:error, :invalid_destination}

  defp resolve_name(host) do
    name = String.to_charlist(host)

    addresses =
      [:inet6, :inet]
      |> Enum.flat_map(fn family ->
        case :inet.getaddrs(name, family) do
          {:ok, resolved} -> resolved
          {:error, _reason} -> []
        end
      end)
      |> Enum.uniq()

    if addresses == [], do: {:error, :unresolved_destination}, else: {:ok, addresses}
  end
end
