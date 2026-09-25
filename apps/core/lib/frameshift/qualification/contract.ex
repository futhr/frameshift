defmodule Frameshift.Qualification.Contract do
  @moduledoc """
  Software revisions this host can actually execute for a qualified binding.

  Changing a renderer protocol, algorithm, or transfer connector requires a
  deliberate code change and fresh conformance evidence before admission.
  """

  @renderer_protocol "fsr1"
  @renderer_algorithm "frameshift-raster-v0.1"
  @connectors %{
    "push" => "wotex-http-v0.1",
    "pull" => "frameshift-outbox-v0.1"
  }

  @doc "Checks a candidate against executable local software revisions."
  @spec validate(map()) :: :ok | {:error, :unsupported_qualification_contract}
  def validate(document) when is_map(document) do
    if document["rendererProtocolRevision"] == @renderer_protocol and
         document["rendererAlgorithmRevision"] == @renderer_algorithm and
         document["connectorRevision"] == @connectors[document["transferMode"]],
       do: :ok,
       else: {:error, :unsupported_qualification_contract}
  end

  def validate(_), do: {:error, :unsupported_qualification_contract}
end
