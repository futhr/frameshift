defmodule FrameshiftBuild.Resolution do
  @moduledoc "Resolves exact canonical profile bytes through shared budgets and standard cryptography."

  @spec resolve(binary(), [binary()]) :: {:ok, map()} | {:error, binary()}
  def resolve(bytes, profiles) when is_binary(bytes) and is_list(profiles) do
    with :ok <- input_types(profiles),
         {:ok, nil} <- normalize(:frameshift_build@resolution.budget(bytes, profiles)),
         {:ok, identity} <- FrameshiftBuild.build_identity(bytes),
         {:ok, pairs} <- hash_profiles(profiles),
         {:ok, resolution} <- normalize(:frameshift_build@resolution.resolve(bytes, pairs)) do
      {:ok, %{identity: identity, resolution: resolution}}
    end
  end

  def resolve(_, _), do: {:error, "invalid_document"}

  defp input_types(profiles) when length(profiles) <= 64 do
    if Enum.all?(profiles, &is_binary/1), do: :ok, else: {:error, "invalid_document"}
  end

  defp input_types(profiles) when length(profiles) > 64, do: {:error, "invalid_count"}
  defp input_types(_), do: {:error, "invalid_document"}

  defp hash_profiles(profiles) do
    Enum.reduce_while(profiles, {:ok, []}, fn bytes, {:ok, acc} ->
      case FrameshiftBuild.profile_identity(bytes) do
        {:ok, identity} -> {:cont, {:ok, [{identity, bytes} | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp normalize({:ok, value}), do: {:ok, value}
  defp normalize({:error, error}), do: {:error, :frameshift_build.refusal_code(error)}
end
