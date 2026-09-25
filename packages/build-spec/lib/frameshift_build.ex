defmodule FrameshiftBuild do
  @moduledoc """
  Canonical physical planning identities shared with the browser's Gleam codecs.

  A valid document preserves claims and provenance. It does not grant assembly
  compatibility, source authenticity, safety qualification or purchasing rights.
  """

  @doc "Validates canonical bytes and returns their versioned SHA-256 identity."
  @spec profile_identity(binary()) :: {:ok, binary()} | {:error, binary()}
  def profile_identity(bytes) when is_binary(bytes) do
    case :frameshift_build.identity_payload(bytes) do
      {:ok, payload} ->
        {:ok, digest(payload)}

      {:error, refusal} ->
        {:error, :frameshift_build.refusal_code(refusal)}
    end
  end

  def profile_identity(_), do: {:error, "invalid_document"}

  @doc "Validates canonical assembly structure and returns its versioned identity."
  @spec build_identity(binary()) :: {:ok, binary()} | {:error, binary()}
  def build_identity(bytes) when is_binary(bytes) do
    case :frameshift_build@assembly.identity_payload(bytes) do
      {:ok, payload} -> {:ok, digest(payload)}
      {:error, refusal} -> {:error, :frameshift_build.refusal_code(refusal)}
    end
  end

  def build_identity(_), do: {:error, "invalid_document"}

  @doc "Validates sourced signal mapping bytes and returns their immutable identity."
  @spec mapping_identity(binary()) :: {:ok, binary()} | {:error, binary()}
  def mapping_identity(bytes) when is_binary(bytes) do
    case :frameshift_build@mapping.identity_payload(bytes) do
      {:ok, payload} -> {:ok, digest(payload)}
      {:error, refusal} -> {:error, :frameshift_build.refusal_code(refusal)}
    end
  end

  def mapping_identity(_), do: {:error, "invalid_document"}

  @doc "Validates intended artifact layout bytes and returns their immutable identity."
  @spec layout_identity(binary()) :: {:ok, binary()} | {:error, binary()}
  def layout_identity(bytes) when is_binary(bytes) do
    case :frameshift_build@artifact.identity_payload(bytes) do
      {:ok, payload} -> {:ok, digest(payload)}
      {:error, refusal} -> {:error, :frameshift_build.refusal_code(refusal)}
    end
  end

  def layout_identity(_), do: {:error, "invalid_document"}

  @doc "Returns exact mapping scope and citations without admitting its evidence."
  @spec inspect_mapping(binary()) :: {:ok, map()} | {:error, binary()}
  def inspect_mapping(bytes) when is_binary(bytes) do
    with {:ok, identity} <- mapping_identity(bytes),
         {:ok, {:document, artifact, firmware, pairs, profile, protocol, 1, sources}} <-
           :frameshift_build@mapping.decode(bytes) do
      {:ok,
       %{
         identity: identity,
         profile: profile,
         artifact: artifact,
         firmware: firmware,
         protocol: protocol,
         pairs: Enum.map(pairs, fn {:pair, input, output} -> %{input: input, output: output} end),
         sources: Enum.map(sources, &source/1)
       }}
    end
  end

  def inspect_mapping(_), do: {:error, "invalid_document"}

  @doc "Returns exact unique profile pins without performing catalog resolution."
  @spec profile_pins(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def profile_pins(bytes) when is_binary(bytes) do
    case :frameshift_build@assembly.profile_pins(bytes) do
      {:ok, pins} -> {:ok, pins}
      {:error, refusal} -> {:error, :frameshift_build.refusal_code(refusal)}
    end
  end

  def profile_pins(_), do: {:error, "invalid_document"}

  @doc "Resolves pinned profile bytes with bounded standard-crypto verification."
  @spec resolve_build(binary(), [binary()]) :: {:ok, map()} | {:error, binary()}
  defdelegate resolve_build(bytes, profiles), to: FrameshiftBuild.Resolution, as: :resolve

  @doc "Resolves exact sourced mappings with assembly/profile inputs and a combined identity."
  @spec resolve_context(binary(), [binary()], [binary()]) :: {:ok, map()} | {:error, binary()}
  defdelegate resolve_context(bytes, profiles, mappings),
    to: FrameshiftBuild.Context,
    as: :resolve

  @doc "Resolves explicit artifact layouts alongside the other pinned planning inputs."
  @spec resolve_context(binary(), [binary()], [binary()], [binary()]) ::
          {:ok, map()} | {:error, binary()}
  defdelegate resolve_context(bytes, profiles, mappings, layouts),
    to: FrameshiftBuild.Context,
    as: :resolve

  @doc "Returns validated immutable metadata and exact fact-to-source citations."
  @spec inspect_profile(binary()) :: {:ok, map()} | {:error, binary()}
  def inspect_profile(bytes) when is_binary(bytes) do
    case :frameshift_build.inspect_profile(bytes) do
      {:ok, {:inspection, payload, id, revision, kind, classes, citations}} ->
        {:ok,
         %{
           identity: digest(payload),
           profile_key: id,
           profile_revision: revision,
           kind: kind,
           classes: classes,
           citations: Enum.map(citations, &citation/1)
         }}

      {:error, refusal} ->
        {:error, :frameshift_build.refusal_code(refusal)}
    end
  end

  def inspect_profile(_), do: {:error, "invalid_document"}

  defp digest(payload),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, payload), case: :lower)

  defp citation({:citation, port, key, {:source, digest, evidence, locator, revision}}) do
    %{
      "port_id" => port,
      "fact_key" => key,
      "digest" => digest,
      "evidence" => evidence,
      "locator" => locator,
      "revision" => revision
    }
  end

  defp source({:source, digest, evidence, locator, revision}) do
    %{"digest" => digest, "evidence" => evidence, "locator" => locator, "revision" => revision}
  end
end
