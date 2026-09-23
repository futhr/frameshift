defmodule Frameshift.DirectSync.Artifact do
  @moduledoc """
  Immutable rendered artifact admitted for one direct frame synchronization.

  Inspection deliberately omits the artwork bytes. Construction verifies the
  content address before any Form is selected or credential is resolved.
  """

  alias Frameshift.Digest

  @derive {Inspect, only: [:digest, :profile_id, :media_type, :byte_count]}
  @enforce_keys [:bytes, :digest, :profile_id, :media_type, :byte_count]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          bytes: binary(),
          digest: String.t(),
          profile_id: String.t(),
          media_type: String.t(),
          byte_count: pos_integer()
        }

  @doc "Constructs a bounded, content addressed artifact for direct frame delivery."
  @spec new(binary(), String.t(), String.t(), String.t()) ::
          {:ok, t()} | {:error, :invalid_artifact}
  def new(bytes, digest, profile_id, media_type)
      when is_binary(bytes) and byte_size(bytes) > 0 and is_binary(digest) and
             is_binary(profile_id) and is_binary(media_type) do
    if byte_size(profile_id) in 1..256 and byte_size(media_type) in 1..128 and
         Digest.valid_sha256?(digest) and Digest.sha256(bytes) == digest do
      {:ok,
       %__MODULE__{
         bytes: bytes,
         digest: digest,
         profile_id: profile_id,
         media_type: media_type,
         byte_count: byte_size(bytes)
       }}
    else
      {:error, :invalid_artifact}
    end
  end

  def new(_bytes, _digest, _profile_id, _media_type), do: {:error, :invalid_artifact}
end
