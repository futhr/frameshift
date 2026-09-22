defmodule Frameshift.Library do
  @moduledoc """
  Single owner of Frameshift library metadata and content relationships.

  Public calls are serialized through this process. The SQLite connection is
  never returned to callers.
  """

  use GenServer

  alias Frameshift.ContentStore
  alias Frameshift.Digest
  alias Frameshift.Library.Migrations
  alias Frameshift.Protocol.Schema

  @type server :: GenServer.server()
  @type digest :: String.t()
  @maximum_read_bytes 128 * 1024 * 1024

  @required_master_fields ~w(title source_kind width height media_type provenance)a
  @label_provenance ~w(user vision filename metadata)a
  @frame_roles ["desired", "current", "previous-known-good", "queued", "playlist"]

  defmodule State do
    @moduledoc false
    @enforce_keys [:connection, :data_dir]
    defstruct [:connection, :data_dir]
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec import_master(server(), iodata(), map()) :: {:ok, map()} | {:error, term()}
  def import_master(server \\ __MODULE__, bytes, attributes) do
    GenServer.call(server, {:import_master, bytes, attributes}, :infinity)
  end

  @spec register_recipe(server(), :generation | :composition, map(), [digest()]) ::
          {:ok, digest()} | {:error, term()}
  def register_recipe(server \\ __MODULE__, kind, parameters, source_digests \\ []) do
    GenServer.call(server, {:register_recipe, kind, parameters, source_digests})
  end

  @spec add_generated_variant(server(), iodata(), map(), digest(), digest()) ::
          {:ok, map()} | {:error, term()}
  def add_generated_variant(
        server \\ __MODULE__,
        bytes,
        attributes,
        parent_digest,
        generation_recipe_hash
      ) do
    GenServer.call(
      server,
      {:add_generated_variant, bytes, attributes, parent_digest, generation_recipe_hash},
      :infinity
    )
  end

  @spec add_generated_master(server(), iodata(), map(), digest()) ::
          {:ok, map()} | {:error, term()}
  def add_generated_master(server \\ __MODULE__, bytes, attributes, generation_recipe_hash) do
    GenServer.call(
      server,
      {:add_generated_master, bytes, attributes, generation_recipe_hash},
      :infinity
    )
  end

  @spec cached_generation(server(), digest()) :: {:ok, map()} | :not_found
  def cached_generation(server \\ __MODULE__, recipe_hash) do
    GenServer.call(server, {:cached_generation, recipe_hash})
  end

  @spec register_artifact(server(), iodata(), map()) :: {:ok, map()} | {:error, term()}
  def register_artifact(server \\ __MODULE__, bytes, attributes) do
    GenServer.call(server, {:register_artifact, bytes, attributes}, :infinity)
  end

  @spec cached_artifact(server(), digest(), String.t(), String.t()) :: {:ok, map()} | :not_found
  def cached_artifact(server \\ __MODULE__, recipe_hash, profile_id, renderer_revision) do
    GenServer.call(server, {:cached_artifact, recipe_hash, profile_id, renderer_revision})
  end

  @spec add_label(server(), digest(), String.t(), atom(), number() | nil, String.t() | nil) ::
          :ok | {:error, term()}
  def add_label(
        server \\ __MODULE__,
        digest,
        label,
        provenance,
        confidence \\ nil,
        revision \\ nil
      ) do
    GenServer.call(server, {:add_label, digest, label, provenance, confidence, revision})
  end

  @spec search(server(), String.t(), keyword()) :: [map()]
  def search(server \\ __MODULE__, query, options \\ []) do
    GenServer.call(server, {:search, query, options})
  end

  @spec pin(server(), digest()) :: :ok | {:error, term()}
  def pin(server \\ __MODULE__, digest), do: GenServer.call(server, {:pin, digest})

  @spec unpin(server(), digest()) :: :ok | {:error, term()}
  def unpin(server \\ __MODULE__, digest), do: GenServer.call(server, {:unpin, digest})

  @spec remove_master(server(), digest()) :: :ok | {:error, term()}
  def remove_master(server \\ __MODULE__, digest),
    do: GenServer.call(server, {:remove_master, digest})

  @spec restore_master(server(), digest()) :: :ok | {:error, term()}
  def restore_master(server \\ __MODULE__, digest),
    do: GenServer.call(server, {:restore_master, digest})

  @spec protect_frame_asset(server(), String.t(), String.t(), digest()) :: :ok | {:error, term()}
  def protect_frame_asset(server \\ __MODULE__, frame_id, role, digest) do
    GenServer.call(server, {:protect_frame_asset, frame_id, role, digest})
  end

  @spec release_frame_asset(server(), String.t(), String.t(), digest()) :: :ok
  def release_frame_asset(server \\ __MODULE__, frame_id, role, digest) do
    GenServer.call(server, {:release_frame_asset, frame_id, role, digest})
  end

  @spec collect_removed(server()) :: {:ok, [digest()]}
  def collect_removed(server \\ __MODULE__),
    do: GenServer.call(server, :collect_removed, :infinity)

  @spec get_master(server(), digest()) :: {:ok, map()} | :not_found
  def get_master(server \\ __MODULE__, digest), do: GenServer.call(server, {:get_master, digest})

  @spec read_object(server(), digest(), pos_integer()) ::
          {:ok, map()} | :not_found | {:error, term()}
  def read_object(server \\ __MODULE__, digest, maximum_bytes \\ @maximum_read_bytes) do
    GenServer.call(server, {:read_object, digest, maximum_bytes}, :infinity)
  end

  @spec queue_outbox(server(), String.t(), digest(), String.t(), digest() | nil) ::
          {:ok, map()} | {:error, term()}
  def queue_outbox(server \\ __MODULE__, frame_id, digest, profile_id, playlist_revision \\ nil) do
    GenServer.call(
      server,
      {:queue_outbox, frame_id, digest, profile_id, playlist_revision}
    )
  end

  @spec outbox_manifest(server(), String.t()) :: {:ok, map()} | :empty
  def outbox_manifest(server \\ __MODULE__, frame_id) do
    GenServer.call(server, {:outbox_manifest, frame_id})
  end

  @spec acknowledge_outbox(server(), String.t(), map()) ::
          :ok | {:ok, :pending} | {:error, term()}
  def acknowledge_outbox(server \\ __MODULE__, frame_id, acknowledgement) do
    GenServer.call(server, {:acknowledge_outbox, frame_id, acknowledgement})
  end

  @impl true
  def init(options) do
    data_dir = options |> Keyword.fetch!(:data_dir) |> Path.expand()

    with :ok <- ContentStore.prepare(data_dir),
         {:ok, connection} <-
           Exqlite.start_link(
             database: Path.join(data_dir, "metadata.sqlite"),
             journal_mode: :wal,
             synchronous: :full,
             foreign_keys: :on,
             default_transaction_mode: :immediate,
             busy_timeout: 2_000
           ),
         :ok <- Migrations.run(connection),
         :ok <- reconcile_objects(connection, data_dir) do
      {:ok, %State{connection: connection, data_dir: data_dir}}
    end
  end

  @impl true
  def terminate(_reason, %State{connection: connection}) do
    if Process.alive?(connection), do: GenServer.stop(connection)
    :ok
  end

  @impl true
  def handle_call({:import_master, bytes, attributes}, _from, state) do
    {:reply, import_master_record(state, bytes, attributes, nil, nil), state}
  end

  def handle_call(
        {:add_generated_variant, bytes, attributes, parent_digest, recipe_hash},
        _from,
        state
      ) do
    attributes = Map.put(attributes, :source_kind, :generated)
    {:reply, import_master_record(state, bytes, attributes, parent_digest, recipe_hash), state}
  end

  def handle_call({:add_generated_master, bytes, attributes, recipe_hash}, _from, state) do
    attributes = Map.put(attributes, :source_kind, :generated)
    {:reply, import_master_record(state, bytes, attributes, nil, recipe_hash), state}
  end

  def handle_call({:cached_generation, recipe_hash}, _from, state) do
    {:reply, cached_generation_record(state, recipe_hash), state}
  end

  def handle_call({:register_recipe, kind, parameters, source_digests}, _from, state) do
    {:reply, do_register_recipe(state, kind, parameters, source_digests), state}
  end

  def handle_call({:register_artifact, bytes, attributes}, _from, state) do
    {:reply, do_register_artifact(state, bytes, attributes), state}
  end

  def handle_call({:cached_artifact, recipe_hash, profile_id, renderer_revision}, _from, state) do
    result =
      query_one(
        state.connection,
        """
        SELECT o.digest, o.byte_count, o.media_type, a.master_digest, a.recipe_hash,
               a.profile_id, a.renderer_revision
        FROM artifacts a
        JOIN objects o ON o.digest = a.digest
        WHERE a.recipe_hash = ? AND a.profile_id = ? AND a.renderer_revision = ?
        """,
        [recipe_hash, profile_id, renderer_revision]
      )

    {:reply, result, state}
  end

  def handle_call({:add_label, digest, label, provenance, confidence, revision}, _from, state) do
    result = add_label_record(state, digest, label, provenance, confidence, revision)
    {:reply, result, state}
  end

  def handle_call({:search, query, options}, _from, state) do
    {:reply, search_records(state, query, options), state}
  end

  def handle_call({:pin, digest}, _from, state) do
    result =
      write_existing_object(state, digest, fn ->
        execute(
          state.connection,
          "INSERT INTO pins(object_digest, pinned_at_ms) VALUES (?, ?) ON CONFLICT DO NOTHING",
          [digest, now_ms()]
        )
      end)

    {:reply, result, state}
  end

  def handle_call({:unpin, digest}, _from, state) do
    execute(state.connection, "DELETE FROM pins WHERE object_digest = ?", [digest])
    {:reply, :ok, state}
  end

  def handle_call({:remove_master, digest}, _from, state) do
    result =
      write_existing_master(state, digest, fn ->
        execute(state.connection, "UPDATE masters SET removed_at_ms = ? WHERE digest = ?", [
          now_ms(),
          digest
        ])
      end)

    {:reply, result, state}
  end

  def handle_call({:restore_master, digest}, _from, state) do
    result = restore_master_record(state, digest)
    {:reply, result, state}
  end

  def handle_call({:protect_frame_asset, frame_id, role, digest}, _from, state) do
    result = protect_frame_asset_record(state, frame_id, role, digest)
    {:reply, result, state}
  end

  def handle_call({:release_frame_asset, frame_id, role, digest}, _from, state) do
    execute(
      state.connection,
      "DELETE FROM frame_asset_refs WHERE frame_id = ? AND role = ? AND object_digest = ?",
      [frame_id, role, digest]
    )

    {:reply, :ok, state}
  end

  def handle_call(:collect_removed, _from, state) do
    {:reply, collect_removed_records(state), state}
  end

  def handle_call({:get_master, digest}, _from, state) do
    {:reply, get_master_record(state, digest), state}
  end

  def handle_call({:read_object, digest, maximum_bytes}, _from, state) do
    {:reply, read_object_record(state, digest, maximum_bytes), state}
  end

  def handle_call({:queue_outbox, frame_id, digest, profile_id, playlist_revision}, _from, state) do
    result = queue_outbox_record(state, frame_id, digest, profile_id, playlist_revision)
    {:reply, result, state}
  end

  def handle_call({:outbox_manifest, frame_id}, _from, state) do
    {:reply, outbox_manifest_record(state, frame_id), state}
  end

  def handle_call({:acknowledge_outbox, frame_id, acknowledgement}, _from, state) do
    {:reply, acknowledge_outbox_record(state, frame_id, acknowledgement), state}
  end

  defp import_master_record(state, bytes, attributes, parent_digest, recipe_hash) do
    with :ok <- validate_master_attributes(attributes),
         :ok <- validate_master_relationship(attributes, parent_digest, recipe_hash),
         :ok <- validate_parent_recipe(state, parent_digest, recipe_hash),
         :not_found <- existing_generation(state, recipe_hash),
         {:ok, digest, byte_count, placement} <- ContentStore.put(state.data_dir, bytes) do
      insert_master(state, digest, byte_count, attributes, parent_digest, recipe_hash, placement)
    else
      {:cached, master} -> {:ok, Map.put(master, :placement, :existing)}
      error -> error
    end
  rescue
    error in Exqlite.Error -> {:error, {:database, error.message}}
  end

  defp existing_generation(_state, nil), do: :not_found

  defp existing_generation(state, recipe_hash) do
    case cached_generation_record(state, recipe_hash) do
      {:ok, master} -> {:cached, master}
      :not_found -> :not_found
    end
  end

  defp validate_master_attributes(attributes) when is_map(attributes) do
    missing = Enum.reject(@required_master_fields, &Map.has_key?(attributes, &1))

    if missing == [],
      do: validate_master_values(attributes),
      else: {:error, {:missing_fields, missing}}
  end

  defp validate_master_attributes(_attributes), do: {:error, :invalid_attributes}

  defp validate_master_relationship(%{source_kind: :import}, nil, nil), do: :ok

  defp validate_master_relationship(%{source_kind: :generated}, _parent, recipe_hash)
       when is_binary(recipe_hash),
       do: :ok

  defp validate_master_relationship(_attributes, _parent, _recipe_hash),
    do: {:error, :invalid_master_relationship}

  defp validate_master_values(attributes) do
    validations = [
      {attributes.source_kind in [:import, :generated], :invalid_source_kind},
      {is_integer(attributes.width) and attributes.width > 0, :invalid_width},
      {is_integer(attributes.height) and attributes.height > 0, :invalid_height},
      {is_binary(attributes.title) and String.trim(attributes.title) != "", :invalid_title},
      {is_binary(attributes.media_type), :invalid_media_type}
    ]

    case Enum.find(validations, fn {valid?, _error} -> not valid? end) do
      nil -> :ok
      {_valid?, error} -> {:error, error}
    end
  end

  defp validate_parent_recipe(_state, nil, nil), do: :ok

  defp validate_parent_recipe(state, nil, recipe_hash) do
    with true <- Digest.valid_sha256?(recipe_hash),
         {:ok, %{"kind" => "generation"}} <-
           query_one(state.connection, "SELECT kind FROM recipes WHERE hash = ?", [recipe_hash]) do
      :ok
    else
      false -> {:error, :invalid_digest}
      :not_found -> {:error, :parent_or_recipe_missing}
      {:ok, _wrong_kind} -> {:error, :not_generation_recipe}
    end
  end

  defp validate_parent_recipe(state, parent_digest, recipe_hash) do
    with true <- Digest.valid_sha256?(parent_digest),
         true <- Digest.valid_sha256?(recipe_hash),
         {:ok, _master} <- get_master_record(state, parent_digest),
         {:ok, %{"kind" => "generation"}} <-
           query_one(state.connection, "SELECT kind FROM recipes WHERE hash = ?", [recipe_hash]) do
      :ok
    else
      false -> {:error, :invalid_digest}
      :not_found -> {:error, :parent_or_recipe_missing}
      {:ok, _wrong_kind} -> {:error, :not_generation_recipe}
    end
  end

  defp insert_master(
         state,
         digest,
         byte_count,
         attributes,
         parent_digest,
         recipe_hash,
         placement
       ) do
    now = now_ms()
    provenance_json = RFC8785.encode!(attributes.provenance)
    source_kind = Atom.to_string(attributes.source_kind)
    orientation = Map.get(attributes, :orientation, 1)
    color_profile = Map.get(attributes, :color_profile)

    transaction(state.connection, fn connection ->
      Exqlite.query!(
        connection,
        """
        INSERT INTO objects(digest, byte_count, media_type, storage_state, created_at_ms)
        VALUES (?, ?, ?, 'active', ?)
        ON CONFLICT(digest) DO UPDATE SET storage_state = 'active', trashed_at_ms = NULL
        """,
        [digest, byte_count, attributes.media_type, now]
      )

      Exqlite.query!(
        connection,
        """
        INSERT INTO masters(
          digest, title, source_kind, width, height, color_profile, orientation,
          provenance_json, parent_digest, generation_recipe_hash, removed_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ON CONFLICT(digest) DO UPDATE SET removed_at_ms = NULL
        """,
        [
          digest,
          attributes.title,
          source_kind,
          attributes.width,
          attributes.height,
          color_profile,
          orientation,
          provenance_json,
          parent_digest,
          recipe_hash
        ]
      )

      if recipe_hash do
        Exqlite.query!(
          connection,
          """
          INSERT INTO generation_results(
            recipe_hash, master_digest, provider_result_id, provenance_json, created_at_ms
          ) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(recipe_hash) DO UPDATE SET
            master_digest = excluded.master_digest,
            provider_result_id = excluded.provider_result_id,
            provenance_json = excluded.provenance_json,
            created_at_ms = excluded.created_at_ms
          """,
          [
            recipe_hash,
            digest,
            Map.get(attributes.provenance, "resultId"),
            provenance_json,
            now
          ]
        )
      end

      audit(connection, "master.imported", digest, %{"sourceKind" => source_kind})
      :ok
    end)
    |> case do
      {:ok, :ok} -> inserted_master_record(state, digest, recipe_hash, placement)
      {:error, %Exqlite.Error{message: message}} -> {:error, {:database, message}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp inserted_master_record(state, digest, nil, placement) do
    with {:ok, master} <- get_master_record(state, digest),
         do: {:ok, Map.put(master, :placement, placement)}
  end

  defp inserted_master_record(state, _digest, recipe_hash, placement) do
    with {:ok, master} <- cached_generation_record(state, recipe_hash),
         do: {:ok, Map.put(master, :placement, placement)}
  end

  defp do_register_recipe(state, kind, parameters, source_digests)
       when kind in [:generation, :composition] and is_map(parameters) and is_list(source_digests) do
    with true <- Enum.all?(source_digests, &Digest.valid_sha256?/1),
         :ok <- validate_recipe_sources(state, source_digests),
         {:ok, canonical_json} <- RFC8785.encode(parameters) do
      kind_string = Atom.to_string(kind)

      hash =
        Digest.sha256([
          kind_string,
          <<0>>,
          canonical_json,
          <<0>>,
          Enum.join(source_digests, <<0>>)
        ])

      result = insert_recipe_transaction(state, hash, kind_string, canonical_json, source_digests)

      case result do
        {:ok, ^hash} -> {:ok, hash}
        {:error, %Exqlite.Error{message: message}} -> {:error, {:database, message}}
        {:error, reason} -> {:error, reason}
      end
    else
      false -> {:error, :invalid_source_digest}
      {:error, :source_missing} -> {:error, :source_missing}
      {:error, reason} -> {:error, {:canonicalization, reason}}
    end
  end

  defp do_register_recipe(_state, _kind, _parameters, _source_digests),
    do: {:error, :invalid_recipe}

  defp insert_recipe_transaction(state, hash, kind, canonical_json, source_digests) do
    transaction(state.connection, fn connection ->
      Exqlite.query!(
        connection,
        "INSERT INTO recipes(hash, kind, canonical_json, created_at_ms) VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING",
        [hash, kind, canonical_json, now_ms()]
      )

      source_digests
      |> Enum.with_index()
      |> Enum.each(fn {source_digest, ordinal} ->
        Exqlite.query!(
          connection,
          "INSERT INTO recipe_sources(recipe_hash, source_digest, ordinal) VALUES (?, ?, ?) ON CONFLICT DO NOTHING",
          [hash, source_digest, ordinal]
        )
      end)

      audit(connection, "recipe.registered", hash, %{"kind" => kind})
      hash
    end)
  end

  defp validate_recipe_sources(state, source_digests) do
    if Enum.all?(source_digests, fn digest ->
         match?({:ok, _master}, get_master_record(state, digest))
       end) do
      :ok
    else
      {:error, :source_missing}
    end
  end

  defp do_register_artifact(state, bytes, attributes) when is_map(attributes) do
    required = ~w(master_digest recipe_hash profile_id renderer_revision media_type)a
    missing = Enum.reject(required, &Map.has_key?(attributes, &1))

    if missing == [],
      do: fetch_or_insert_artifact(state, bytes, attributes),
      else: {:error, {:missing_fields, missing}}
  end

  defp do_register_artifact(_state, _bytes, _attributes), do: {:error, :invalid_attributes}

  defp fetch_or_insert_artifact(state, bytes, attributes) do
    case cached_artifact_record(
           state,
           attributes.recipe_hash,
           attributes.profile_id,
           attributes.renderer_revision
         ) do
      {:ok, artifact} -> cached_artifact_result(artifact, attributes.master_digest)
      :not_found -> insert_artifact(state, bytes, attributes)
    end
  end

  defp cached_artifact_result(%{"master_digest" => master_digest} = artifact, master_digest),
    do: {:ok, Map.put(artifact, :cache, :hit)}

  defp cached_artifact_result(_artifact, _master_digest), do: {:error, :cache_identity_conflict}

  defp insert_artifact(state, bytes, attributes) do
    with {:ok, _master} <- get_master_record(state, attributes.master_digest),
         {:ok, _recipe} <-
           query_one(state.connection, "SELECT hash FROM recipes WHERE hash = ?", [
             attributes.recipe_hash
           ]),
         {:ok, digest, byte_count, placement} <- ContentStore.put(state.data_dir, bytes) do
      result =
        transaction(state.connection, fn connection ->
          Exqlite.query!(
            connection,
            """
            INSERT INTO objects(digest, byte_count, media_type, storage_state, created_at_ms)
            VALUES (?, ?, ?, 'active', ?)
            ON CONFLICT(digest) DO NOTHING
            """,
            [digest, byte_count, attributes.media_type, now_ms()]
          )

          Exqlite.query!(
            connection,
            """
            INSERT INTO artifacts(digest, master_digest, recipe_hash, profile_id, renderer_revision)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
              digest,
              attributes.master_digest,
              attributes.recipe_hash,
              attributes.profile_id,
              attributes.renderer_revision
            ]
          )

          audit(connection, "artifact.registered", digest, %{"profileId" => attributes.profile_id})

          :ok
        end)

      case result do
        {:ok, :ok} ->
          {:ok, artifact} =
            cached_artifact_record(
              state,
              attributes.recipe_hash,
              attributes.profile_id,
              attributes.renderer_revision
            )

          {:ok, artifact |> Map.put(:cache, :miss) |> Map.put(:placement, placement)}

        {:error, %Exqlite.Error{message: message}} ->
          {:error, {:database, message}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      :not_found -> {:error, :master_or_recipe_missing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cached_artifact_record(state, recipe_hash, profile_id, renderer_revision) do
    query_one(
      state.connection,
      """
      SELECT o.digest, o.byte_count, o.media_type, a.master_digest, a.recipe_hash,
             a.profile_id, a.renderer_revision
      FROM artifacts a
      JOIN objects o ON o.digest = a.digest
      WHERE a.recipe_hash = ? AND a.profile_id = ? AND a.renderer_revision = ?
      """,
      [recipe_hash, profile_id, renderer_revision]
    )
  end

  defp add_label_record(state, digest, label, provenance, confidence, revision)
       when provenance in @label_provenance and is_binary(label) do
    trimmed = String.trim(label)

    cond do
      trimmed == "" ->
        {:error, :invalid_label}

      confidence != nil and (not is_number(confidence) or confidence < 0 or confidence > 1) ->
        {:error, :invalid_confidence}

      true ->
        write_existing_master(state, digest, fn ->
          execute(
            state.connection,
            """
            INSERT INTO labels(master_digest, label, provenance, confidence, revision)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(master_digest, label, provenance)
            DO UPDATE SET confidence = excluded.confidence, revision = excluded.revision
            """,
            [digest, trimmed, Atom.to_string(provenance), confidence, revision]
          )
        end)
    end
  end

  defp add_label_record(_state, _digest, _label, _provenance, _confidence, _revision),
    do: {:error, :invalid_label}

  defp search_records(state, query, options) do
    limit = options |> Keyword.get(:limit, 50) |> min(100) |> max(1)
    pinned_only = Keyword.get(options, :pinned, false)
    escaped = escape_like(String.trim(query))
    pattern = "%#{escaped}%"

    pin_clause = if pinned_only, do: "AND p.object_digest IS NOT NULL", else: ""

    sql = """
    SELECT DISTINCT m.digest, m.title, m.source_kind, m.width, m.height,
           m.color_profile, m.orientation, m.provenance_json, m.parent_digest,
           m.generation_recipe_hash, (p.object_digest IS NOT NULL) AS pinned
    FROM masters m
    LEFT JOIN labels l ON l.master_digest = m.digest
    LEFT JOIN pins p ON p.object_digest = m.digest
    WHERE m.removed_at_ms IS NULL
      AND (? = '' OR m.title LIKE ? ESCAPE '\\' OR l.label LIKE ? ESCAPE '\\')
      #{pin_clause}
    ORDER BY pinned DESC, m.title COLLATE NOCASE, m.digest
    LIMIT ?
    """

    state.connection
    |> Exqlite.query!(sql, [String.trim(query), pattern, pattern, limit])
    |> rows_to_maps()
    |> Enum.map(&decode_master_row/1)
  end

  defp restore_master_record(state, digest) do
    with {:ok, %{"storage_state" => storage_state}} <-
           query_one(
             state.connection,
             "SELECT o.storage_state FROM masters m JOIN objects o ON o.digest = m.digest WHERE m.digest = ?",
             [digest]
           ),
         :ok <- maybe_restore_file(state, digest, storage_state),
         :ok <-
           execute(state.connection, "UPDATE masters SET removed_at_ms = NULL WHERE digest = ?", [
             digest
           ]),
         :ok <-
           execute(
             state.connection,
             "UPDATE objects SET storage_state = 'active', trashed_at_ms = NULL WHERE digest = ?",
             [digest]
           ) do
      :ok
    else
      :not_found -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_restore_file(_state, _digest, "active"), do: :ok

  defp maybe_restore_file(state, digest, "trash"),
    do: ContentStore.restore(state.data_dir, digest)

  defp protect_frame_asset_record(state, frame_id, role, digest)
       when is_binary(frame_id) and frame_id != "" and role in @frame_roles do
    write_existing_object(state, digest, fn ->
      execute(
        state.connection,
        "INSERT INTO frame_asset_refs(frame_id, role, object_digest) VALUES (?, ?, ?) ON CONFLICT DO NOTHING",
        [frame_id, role, digest]
      )
    end)
  end

  defp protect_frame_asset_record(_state, _frame_id, _role, _digest),
    do: {:error, :invalid_frame_reference}

  defp collect_removed_records(state) do
    candidates =
      state.connection
      |> Exqlite.query!("""
      SELECT m.digest
      FROM masters m
      JOIN objects o ON o.digest = m.digest
      WHERE m.removed_at_ms IS NOT NULL
        AND o.storage_state = 'active'
        AND NOT EXISTS (SELECT 1 FROM pins p WHERE p.object_digest = m.digest)
        AND NOT EXISTS (SELECT 1 FROM frame_asset_refs f WHERE f.object_digest = m.digest)
        AND NOT EXISTS (SELECT 1 FROM artifacts a WHERE a.master_digest = m.digest)
        AND NOT EXISTS (SELECT 1 FROM recipe_sources r WHERE r.source_digest = m.digest)
      ORDER BY m.digest
      """)
      |> Map.fetch!(:rows)
      |> Enum.map(&hd/1)

    collected =
      Enum.reduce(candidates, [], fn digest, moved ->
        case ContentStore.move_to_trash(state.data_dir, digest) do
          :ok ->
            :ok =
              execute(
                state.connection,
                "UPDATE objects SET storage_state = 'trash', trashed_at_ms = ? WHERE digest = ?",
                [now_ms(), digest]
              )

            [digest | moved]

          {:error, _reason} ->
            moved
        end
      end)

    {:ok, Enum.reverse(collected)}
  end

  defp get_master_record(state, digest) do
    case query_one(
           state.connection,
           """
           SELECT m.digest, m.title, m.source_kind, m.width, m.height,
                  m.color_profile, m.orientation, m.provenance_json, m.parent_digest,
                  m.generation_recipe_hash, m.removed_at_ms, o.media_type, o.storage_state,
                  (p.object_digest IS NOT NULL) AS pinned
           FROM masters m
           JOIN objects o ON o.digest = m.digest
           LEFT JOIN pins p ON p.object_digest = m.digest
           WHERE m.digest = ?
           """,
           [digest]
         ) do
      {:ok, master} -> {:ok, decode_master_row(master)}
      :not_found -> :not_found
    end
  end

  defp read_object_record(state, digest, maximum_bytes)
       when is_integer(maximum_bytes) and maximum_bytes > 0 do
    case query_one(
           state.connection,
           "SELECT digest, byte_count, media_type, storage_state FROM objects WHERE digest = ?",
           [digest]
         ) do
      {:ok, %{"storage_state" => "active", "byte_count" => byte_count} = object}
      when byte_count <= maximum_bytes ->
        case ContentStore.read(state.data_dir, digest, maximum_bytes) do
          {:ok, bytes} -> {:ok, Map.put(object, "bytes", bytes)}
          {:error, reason} -> {:error, reason}
        end

      {:ok, %{"storage_state" => "active"}} ->
        {:error, :object_too_large}

      {:ok, _trashed} ->
        {:error, :object_in_trash}

      :not_found ->
        :not_found
    end
  end

  defp read_object_record(_state, _digest, _maximum_bytes), do: {:error, :invalid_read}

  defp cached_generation_record(state, recipe_hash) do
    case query_one(
           state.connection,
           """
           SELECT gr.master_digest AS digest, gr.provider_result_id,
                  gr.provenance_json AS generation_provenance_json
           FROM generation_results gr
           JOIN masters m ON m.digest = gr.master_digest
           WHERE gr.recipe_hash = ? AND m.removed_at_ms IS NULL
           """,
           [recipe_hash]
         ) do
      {:ok, generation} -> generation_master_record(state, recipe_hash, generation)
      :not_found -> :not_found
    end
  end

  defp generation_master_record(
         state,
         recipe_hash,
         %{
           "digest" => digest,
           "provider_result_id" => provider_result_id,
           "generation_provenance_json" => provenance_json
         }
       ) do
    with {:ok, master} <- get_master_record(state, digest) do
      generation = %{
        "recipe_hash" => recipe_hash,
        "provider_result_id" => provider_result_id,
        "provenance" => JSON.decode!(provenance_json)
      }

      {:ok, Map.put(master, "generation", generation)}
    end
  end

  defp queue_outbox_record(state, frame_id, digest, profile_id, playlist_revision)
       when is_binary(frame_id) and frame_id != "" and is_binary(profile_id) do
    with true <- Digest.valid_sha256?(digest),
         true <- playlist_revision == nil or Digest.valid_sha256?(playlist_revision),
         :ok <-
           Schema.validate("outbox-manifest", %{
             "revision" => 1,
             "desiredAsset" => digest,
             "artifactProfile" => profile_id,
             "playlistRevision" => playlist_revision
           }),
         {:ok, %{"profile_id" => ^profile_id}} <-
           query_one(
             state.connection,
             "SELECT profile_id FROM artifacts WHERE digest = ?",
             [digest]
           ) do
      result =
        transaction(state.connection, fn connection ->
          revision = next_outbox_revision(connection, frame_id)

          Exqlite.query!(
            connection,
            "DELETE FROM frame_asset_refs WHERE frame_id = ? AND role = 'queued'",
            [frame_id]
          )

          Exqlite.query!(
            connection,
            """
            INSERT INTO frame_outboxes(
              frame_id, revision, desired_digest, profile_id, playlist_revision, queued_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(frame_id) DO UPDATE SET
              revision = excluded.revision,
              desired_digest = excluded.desired_digest,
              profile_id = excluded.profile_id,
              playlist_revision = excluded.playlist_revision,
              queued_at_ms = excluded.queued_at_ms
            """,
            [frame_id, revision, digest, profile_id, playlist_revision, now_ms()]
          )

          Exqlite.query!(
            connection,
            "INSERT INTO frame_asset_refs(frame_id, role, object_digest) VALUES (?, 'queued', ?)",
            [frame_id, digest]
          )

          audit(connection, "outbox.queued", digest, %{
            "frameId" => frame_id,
            "revision" => revision
          })

          revision
        end)

      case result do
        {:ok, _revision} -> outbox_manifest_record(state, frame_id)
        {:error, %Exqlite.Error{message: message}} -> {:error, {:database, message}}
        {:error, reason} -> {:error, reason}
      end
    else
      false -> {:error, :invalid_digest}
      {:error, %JSV.ValidationError{}} -> {:error, :invalid_outbox}
      :not_found -> {:error, :artifact_missing}
      {:ok, _different_profile} -> {:error, :unsupported_profile}
    end
  end

  defp queue_outbox_record(_state, _frame_id, _digest, _profile_id, _playlist_revision),
    do: {:error, :invalid_outbox}

  defp next_outbox_revision(connection, frame_id) do
    connection
    |> Exqlite.query!(
      """
      INSERT INTO frame_outbox_revisions(frame_id, revision)
      VALUES (?, 1)
      ON CONFLICT(frame_id) DO UPDATE SET revision = revision + 1
      RETURNING revision
      """,
      [frame_id]
    )
    |> Map.fetch!(:rows)
    |> then(fn [[revision]] -> revision end)
  end

  defp outbox_manifest_record(state, frame_id) do
    case query_one(
           state.connection,
           """
           SELECT revision, desired_digest, profile_id, playlist_revision
           FROM frame_outboxes
           WHERE frame_id = ?
           """,
           [frame_id]
         ) do
      {:ok, row} ->
        {:ok,
         %{
           "revision" => row["revision"],
           "desiredAsset" => row["desired_digest"],
           "artifactProfile" => row["profile_id"],
           "playlistRevision" => row["playlist_revision"]
         }}

      :not_found ->
        :empty
    end
  end

  defp acknowledge_outbox_record(state, frame_id, acknowledgement) when is_binary(frame_id) do
    with :ok <- Schema.validate("outbox-ack", acknowledgement),
         {:ok, manifest} <- outbox_manifest_record(state, frame_id),
         :ok <- validate_acknowledgement(manifest, acknowledgement) do
      if acknowledgement["refresh"] == "displayed" do
        commit_outbox_acknowledgement(state, frame_id, manifest)
      else
        {:ok, :pending}
      end
    else
      :empty -> {:error, :outbox_empty}
      {:error, %JSV.ValidationError{}} -> {:error, :invalid_acknowledgement}
      {:error, reason} -> {:error, reason}
    end
  end

  defp acknowledge_outbox_record(_state, _frame_id, _acknowledgement),
    do: {:error, :invalid_acknowledgement}

  defp validate_acknowledgement(manifest, acknowledgement) do
    cond do
      acknowledgement["manifestRevision"] != manifest["revision"] ->
        {:error, :outbox_revision_conflict}

      acknowledgement["refresh"] == "displayed" and acknowledgement["storage"] == "failed" ->
        {:error, :storage_not_verified}

      acknowledgement["refresh"] == "displayed" and
          acknowledgement["currentAsset"] != manifest["desiredAsset"] ->
        {:error, :current_asset_mismatch}

      true ->
        :ok
    end
  end

  defp commit_outbox_acknowledgement(state, frame_id, manifest) do
    digest = manifest["desiredAsset"]

    result =
      transaction(state.connection, fn connection ->
        Exqlite.query!(
          connection,
          "DELETE FROM frame_asset_refs WHERE frame_id = ? AND role = 'previous-known-good'",
          [frame_id]
        )

        Exqlite.query!(
          connection,
          """
          INSERT INTO frame_asset_refs(frame_id, role, object_digest)
          SELECT frame_id, 'previous-known-good', object_digest
          FROM frame_asset_refs
          WHERE frame_id = ? AND role = 'current'
          """,
          [frame_id]
        )

        Exqlite.query!(
          connection,
          "DELETE FROM frame_asset_refs WHERE frame_id = ? AND role IN ('current', 'queued')",
          [frame_id]
        )

        Exqlite.query!(
          connection,
          "INSERT INTO frame_asset_refs(frame_id, role, object_digest) VALUES (?, 'current', ?)",
          [frame_id, digest]
        )

        Exqlite.query!(connection, "DELETE FROM frame_outboxes WHERE frame_id = ?", [frame_id])
        audit(connection, "outbox.acknowledged", digest, %{"frameId" => frame_id})
        :ok
      end)

    case result do
      {:ok, :ok} -> :ok
      {:error, %Exqlite.Error{message: message}} -> {:error, {:database, message}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_master_row(row) do
    row
    |> Map.update("provenance_json", %{}, &JSON.decode!/1)
    |> Map.update("pinned", false, &(&1 == 1))
  end

  defp write_existing_master(state, digest, function) do
    case get_master_record(state, digest) do
      {:ok, _master} -> function.()
      :not_found -> {:error, :not_found}
    end
  end

  defp write_existing_object(state, digest, function) do
    case query_one(state.connection, "SELECT digest FROM objects WHERE digest = ?", [digest]) do
      {:ok, _object} -> function.()
      :not_found -> {:error, :not_found}
    end
  end

  defp execute(connection, sql, parameters) do
    case Exqlite.query(connection, sql, parameters) do
      {:ok, _result} -> :ok
      {:error, %Exqlite.Error{message: message}} -> {:error, {:database, message}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transaction(connection, function) do
    Exqlite.transaction(connection, function, mode: :immediate)
  end

  defp query_one(connection, sql, parameters) do
    case connection |> Exqlite.query!(sql, parameters) |> rows_to_maps() do
      [row] -> {:ok, row}
      [] -> :not_found
    end
  end

  defp rows_to_maps(%Exqlite.Result{columns: columns, rows: rows}) do
    Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
  end

  defp reconcile_objects(connection, data_dir) do
    connection
    |> Exqlite.query!("SELECT digest, storage_state FROM objects ORDER BY digest")
    |> Map.fetch!(:rows)
    |> Enum.reduce_while(:ok, fn [digest, storage_state], :ok ->
      case ContentStore.reconcile(data_dir, digest, storage_state) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp audit(connection, operation, subject_digest, details) do
    Exqlite.query!(
      connection,
      "INSERT INTO audit_entries(operation, subject_digest, detail_json, occurred_at_ms) VALUES (?, ?, ?, ?)",
      [operation, subject_digest, RFC8785.encode!(details), now_ms()]
    )
  end

  defp escape_like(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp now_ms, do: System.os_time(:millisecond)
end
