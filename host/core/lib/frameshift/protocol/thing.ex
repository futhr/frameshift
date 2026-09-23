defmodule Frameshift.Protocol.Thing do
  @moduledoc """
  Bounded W3C WoT admission and deterministic Form selection for Frameshift.

  Wotex owns TD/TM 1.1 parsing and validation. This module applies the
  Frameshift semantic role on top: required profiles, affordance names, and
  the frame capability overlay. It never derives an endpoint from a vendor,
  hardware revision, or assumed route.

  Binding profiles are explicit inputs to selection. The included HTTPS
  profile describes the reference binding's selectable cells; it does not
  resolve credentials or perform network I/O.
  """

  alias Frameshift.Protocol.Schema
  alias Wotex.Runtime.{BindingProfile, FormSelector}
  alias Wotex.{ThingDescription, ThingModel}

  defmodule Error do
    @moduledoc "Stable Frameshift semantic-admission failure."

    @type t :: %__MODULE__{
            code: atom(),
            phase: :semantic,
            path: String.t(),
            message: String.t(),
            details: map()
          }

    @enforce_keys [:code, :message, :path]
    defexception [:code, :message, :path, phase: :semantic, details: %{}]
  end

  @frame_profile "urn:frameshift:profile:frame:0.1"
  @host_outbox_profile "urn:frameshift:profile:host-outbox:0.1"

  @frame_properties ~w(capabilities state playlist)
  @frame_actions ~w(installAsset removeAsset setDesired replacePlaylist retryDisplay)
  @frame_events ~w(stateChanged displayCompleted)
  @outbox_properties ~w(manifest artifact)
  @outbox_actions ~w(acknowledge)

  @td_limits [
    max_bytes: 262_144,
    max_depth: 32,
    max_nodes: 25_000,
    max_string_bytes: 16_384,
    max_collection_size: 4_096
  ]

  @models_dir Path.expand("../../../../../protocol/models", __DIR__)
  @frame_model_path Path.join(@models_dir, "frame.tm.json")
  @host_outbox_model_path Path.join(@models_dir, "host-outbox.tm.json")
  @external_resource @frame_model_path
  @external_resource @host_outbox_model_path
  @frame_model_source File.read!(@frame_model_path)
  @host_outbox_model_source File.read!(@host_outbox_model_path)

  @type role :: :frame | :host_outbox
  @type admission_error :: Wotex.Error.t() | [Wotex.Error.t()] | Error.t()

  @spec frame_profile() :: String.t()
  def frame_profile, do: @frame_profile

  @spec host_outbox_profile() :: String.t()
  def host_outbox_profile, do: @host_outbox_profile

  @doc "Parses and validates a Frame Thing Description under fixed resource limits."
  @spec parse_frame(binary()) ::
          {:ok, ThingDescription.t()} | {:error, admission_error()}
  def parse_frame(source), do: parse(source, :frame)

  @doc "Parses and validates a Host Outbox Thing Description under fixed resource limits."
  @spec parse_host_outbox(binary()) ::
          {:ok, ThingDescription.t()} | {:error, admission_error()}
  def parse_host_outbox(source), do: parse(source, :host_outbox)

  @doc "Returns an embedded, validated Frameshift Thing Model."
  @spec model(role()) :: {:ok, ThingModel.t()} | {:error, Wotex.Error.t() | [Wotex.Error.t()]}
  def model(:frame), do: ThingModel.parse(@frame_model_source, @td_limits)
  def model(:host_outbox), do: ThingModel.parse(@host_outbox_model_source, @td_limits)

  @doc "Builds the reference HTTPS JSON binding declaration used for Form selection."
  @spec reference_https_profile() ::
          {:ok, BindingProfile.t()} | {:error, Wotex.Runtime.Error.t()}
  def reference_https_profile do
    BindingProfile.new(
      id: :frameshift_https_json_v0_1,
      schemes: ["https"],
      operations: Wotex.Runtime.operations(),
      media_types: ["application/json"]
    )
  end

  @doc "Builds the reference HTTPS binary-artifact binding for exact advertised media types."
  @spec reference_https_artifact_profile([String.t()]) ::
          {:ok, BindingProfile.t()} | {:error, Wotex.Runtime.Error.t()}
  def reference_https_artifact_profile(media_types) do
    BindingProfile.new(
      id: :frameshift_https_artifact_v0_1,
      schemes: ["https"],
      operations: [:invokeaction, :readproperty],
      media_types: media_types
    )
  end

  @doc "Selects an advertised frame interaction with caller-supplied binding profiles."
  @spec select_frame(
          ThingDescription.t(),
          :property | :action | :event,
          String.t(),
          Wotex.Runtime.operation(),
          [BindingProfile.t()]
        ) :: {:ok, Wotex.Runtime.Selection.t()} | {:error, Error.t() | Wotex.Runtime.Error.t()}
  def select_frame(%ThingDescription{} = td, type, name, operation, profiles) do
    with :ok <- validate_role(td, :frame) do
      FormSelector.select(td, type, name, operation, profiles)
    end
  end

  @doc "Selects an advertised Host Outbox interaction with explicit binding profiles."
  @spec select_host_outbox(
          ThingDescription.t(),
          :property | :action | :event,
          String.t(),
          Wotex.Runtime.operation(),
          [BindingProfile.t()]
        ) :: {:ok, Wotex.Runtime.Selection.t()} | {:error, Error.t() | Wotex.Runtime.Error.t()}
  def select_host_outbox(%ThingDescription{} = td, type, name, operation, profiles) do
    with :ok <- validate_role(td, :host_outbox) do
      FormSelector.select(td, type, name, operation, profiles)
    end
  end

  defp parse(source, role) do
    with {:ok, td} <- ThingDescription.parse(source, @td_limits),
         :ok <- validate_role(td, role) do
      {:ok, td}
    end
  end

  defp validate_role(%ThingDescription{} = td, :frame) do
    document = ThingDescription.to_map(td)

    with :ok <- validate_profiles(document, @frame_profile),
         :ok <- validate_affordances(document, "properties", @frame_properties),
         :ok <- validate_affordances(document, "actions", @frame_actions),
         :ok <- validate_affordances(document, "events", @frame_events) do
      validate_frame_overlay(document)
    end
  end

  defp validate_role(%ThingDescription{} = td, :host_outbox) do
    document = ThingDescription.to_map(td)

    with :ok <- validate_profiles(document, @host_outbox_profile),
         :ok <- validate_affordances(document, "properties", @outbox_properties) do
      validate_affordances(document, "actions", @outbox_actions)
    end
  end

  defp validate_profiles(document, required) do
    profiles = Map.get(document, "profile")

    cond do
      profiles == [required] ->
        :ok

      is_list(profiles) and required in profiles ->
        semantic_error(
          :unsupported_required_profile,
          "/profile",
          "Thing Description declares an unsupported required profile",
          %{profile_count: length(profiles)}
        )

      true ->
        semantic_error(
          :required_profile_missing,
          "/profile",
          "Thing Description does not declare the required Frameshift profile"
        )
    end
  end

  defp validate_affordances(document, member, required_names) do
    affordances = Map.get(document, member, %{})

    case Enum.find(required_names, &(not is_map(Map.get(affordances, &1)))) do
      nil ->
        :ok

      missing ->
        semantic_error(
          :required_affordance_missing,
          "/#{member}/#{missing}",
          "Thing Description does not declare a required Frameshift affordance",
          %{affordance_kind: member}
        )
    end
  end

  defp validate_frame_overlay(document) do
    case Schema.validate("thing-description", document) do
      :ok ->
        :ok

      {:error, _} ->
        semantic_error(
          :frame_overlay_invalid,
          "/",
          "Thing Description does not satisfy the Frameshift frame overlay"
        )
    end
  end

  defp semantic_error(code, path, message, details \\ %{}) do
    {:error, %Error{code: code, path: path, message: message, details: details}}
  end
end
