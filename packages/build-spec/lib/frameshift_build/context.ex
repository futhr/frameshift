defmodule FrameshiftBuild.Context do
  @moduledoc "Resolves exact physical planning inputs under one shared byte budget."

  alias FrameshiftBuild.Documents

  @spec resolve(binary(), [binary()], [binary()]) :: {:ok, map()} | {:error, binary()}
  @spec resolve(binary(), [binary()], [binary()], [binary()]) :: {:ok, map()} | {:error, binary()}
  def resolve(bytes, profiles, mappings, layouts \\ [])

  def resolve(bytes, profiles, mappings, layouts) when is_binary(bytes) do
    with :ok <- Documents.input_types(profiles),
         :ok <- Documents.input_types(mappings),
         :ok <- Documents.input_types(layouts),
         {:ok, nil} <-
           Documents.normalize(
             :frameshift_build@resolution.complete_budget(bytes, profiles, mappings, layouts)
           ),
         {:ok, assembly} <- FrameshiftBuild.build_identity(bytes),
         {:ok, profiles} <- Documents.hash(profiles, &FrameshiftBuild.profile_identity/1),
         {:ok, mappings} <- Documents.hash(mappings, &FrameshiftBuild.mapping_identity/1),
         {:ok, layouts} <- Documents.hash(layouts, &FrameshiftBuild.layout_identity/1),
         {:ok, context} <-
           Documents.normalize(
             :frameshift_build@context.resolve_all(bytes, profiles, mappings, layouts)
           ),
         {:ok, canonical} <-
           Documents.normalize(:frameshift_build@context.canonical(assembly, context)) do
      identity =
        "sha256:" <>
          Base.encode16(:crypto.hash(:sha256, "frameshift.compilation.v1\n" <> canonical),
            case: :lower
          )

      {:ok,
       %{identity: identity, assembly_identity: assembly, canonical: canonical, context: context}}
    end
  end

  def resolve(_, _, _, _), do: {:error, "invalid_document"}
end
