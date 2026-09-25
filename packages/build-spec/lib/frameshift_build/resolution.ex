defmodule FrameshiftBuild.Resolution do
  @moduledoc "Resolves exact canonical profile bytes through shared budgets and standard cryptography."

  alias FrameshiftBuild.Documents

  @spec resolve(binary(), [binary()]) :: {:ok, map()} | {:error, binary()}
  def resolve(bytes, profiles) when is_binary(bytes) and is_list(profiles) do
    with :ok <- Documents.input_types(profiles),
         {:ok, nil} <- Documents.normalize(:frameshift_build@resolution.budget(bytes, profiles)),
         {:ok, identity} <- FrameshiftBuild.build_identity(bytes),
         {:ok, pairs} <- Documents.hash(profiles, &FrameshiftBuild.profile_identity/1),
         {:ok, resolution} <-
           Documents.normalize(:frameshift_build@resolution.resolve(bytes, pairs)) do
      {:ok, %{identity: identity, resolution: resolution}}
    end
  end

  def resolve(_, _), do: {:error, "invalid_document"}
end
