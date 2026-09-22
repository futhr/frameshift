defmodule Frameshift.Library.Migrations do
  @moduledoc false

  @migrations [
    {1,
     [
       """
       CREATE TABLE objects (
         digest TEXT PRIMARY KEY CHECK (
           length(digest) = 71 AND
           substr(digest, 1, 7) = 'sha256:' AND
           substr(digest, 8) NOT GLOB '*[^0-9a-f]*'
         ),
         byte_count INTEGER NOT NULL CHECK (byte_count >= 0),
         media_type TEXT NOT NULL,
         storage_state TEXT NOT NULL DEFAULT 'active' CHECK (storage_state IN ('active', 'trash')),
         created_at_ms INTEGER NOT NULL,
         trashed_at_ms INTEGER
       ) STRICT
       """,
       """
       CREATE TABLE masters (
         digest TEXT PRIMARY KEY REFERENCES objects(digest) ON DELETE CASCADE,
         title TEXT NOT NULL,
         source_kind TEXT NOT NULL CHECK (source_kind IN ('import', 'generated')),
         width INTEGER NOT NULL CHECK (width > 0),
         height INTEGER NOT NULL CHECK (height > 0),
         color_profile TEXT,
         orientation INTEGER NOT NULL DEFAULT 1 CHECK (orientation BETWEEN 1 AND 8),
         provenance_json TEXT NOT NULL,
         parent_digest TEXT REFERENCES masters(digest) ON DELETE RESTRICT,
         generation_recipe_hash TEXT,
         removed_at_ms INTEGER
       ) STRICT
       """,
       """
       CREATE TABLE recipes (
         hash TEXT PRIMARY KEY CHECK (
           length(hash) = 71 AND
           substr(hash, 1, 7) = 'sha256:' AND
           substr(hash, 8) NOT GLOB '*[^0-9a-f]*'
         ),
         kind TEXT NOT NULL CHECK (kind IN ('generation', 'composition')),
         canonical_json TEXT NOT NULL,
         created_at_ms INTEGER NOT NULL
       ) STRICT
       """,
       """
       CREATE TABLE recipe_sources (
         recipe_hash TEXT NOT NULL REFERENCES recipes(hash) ON DELETE CASCADE,
         source_digest TEXT NOT NULL REFERENCES masters(digest) ON DELETE RESTRICT,
         ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
         PRIMARY KEY (recipe_hash, ordinal),
         UNIQUE (recipe_hash, source_digest, ordinal)
       ) STRICT
       """,
       """
       CREATE TABLE artifacts (
         digest TEXT PRIMARY KEY REFERENCES objects(digest) ON DELETE CASCADE,
         master_digest TEXT NOT NULL REFERENCES masters(digest) ON DELETE RESTRICT,
         recipe_hash TEXT NOT NULL REFERENCES recipes(hash) ON DELETE RESTRICT,
         profile_id TEXT NOT NULL,
         renderer_revision TEXT NOT NULL,
         UNIQUE (master_digest, recipe_hash, profile_id, renderer_revision)
       ) STRICT
       """,
       """
       CREATE TABLE labels (
         master_digest TEXT NOT NULL REFERENCES masters(digest) ON DELETE CASCADE,
         label TEXT NOT NULL COLLATE NOCASE,
         provenance TEXT NOT NULL CHECK (provenance IN ('user', 'vision', 'filename', 'metadata')),
         confidence REAL,
         revision TEXT,
         PRIMARY KEY (master_digest, label, provenance)
       ) STRICT
       """,
       """
       CREATE TABLE pins (
         object_digest TEXT PRIMARY KEY REFERENCES objects(digest) ON DELETE CASCADE,
         pinned_at_ms INTEGER NOT NULL
       ) STRICT
       """,
       """
       CREATE TABLE frame_asset_refs (
         frame_id TEXT NOT NULL,
         role TEXT NOT NULL CHECK (role IN ('desired', 'current', 'previous-known-good', 'queued', 'playlist')),
         object_digest TEXT NOT NULL REFERENCES objects(digest) ON DELETE RESTRICT,
         PRIMARY KEY (frame_id, role, object_digest)
       ) STRICT
       """,
       """
       CREATE TABLE audit_entries (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         operation TEXT NOT NULL,
         subject_digest TEXT,
         detail_json TEXT NOT NULL,
         occurred_at_ms INTEGER NOT NULL
       ) STRICT
       """,
       "CREATE INDEX masters_active_title ON masters(removed_at_ms, title)",
       "CREATE INDEX labels_lookup ON labels(label, master_digest)",
       "CREATE INDEX frame_asset_refs_digest ON frame_asset_refs(object_digest)"
     ]},
    {2,
     [
       """
       CREATE TABLE frame_outbox_revisions (
         frame_id TEXT PRIMARY KEY,
         revision INTEGER NOT NULL CHECK (revision > 0)
       ) STRICT
       """,
       """
       CREATE TABLE frame_outboxes (
         frame_id TEXT PRIMARY KEY REFERENCES frame_outbox_revisions(frame_id) ON DELETE RESTRICT,
         revision INTEGER NOT NULL CHECK (revision > 0),
         desired_digest TEXT NOT NULL REFERENCES objects(digest) ON DELETE RESTRICT,
         profile_id TEXT NOT NULL,
         playlist_revision TEXT,
         queued_at_ms INTEGER NOT NULL
       ) STRICT
       """
     ]}
  ]

  @spec run(pid()) :: :ok | no_return()
  def run(connection) do
    Exqlite.query!(
      connection,
      "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY) STRICT"
    )

    applied =
      connection
      |> Exqlite.query!("SELECT version FROM schema_migrations ORDER BY version")
      |> Map.fetch!(:rows)
      |> MapSet.new(fn [version] -> version end)

    Enum.each(@migrations, fn {version, statements} ->
      unless MapSet.member?(applied, version), do: migrate(connection, version, statements)
    end)

    :ok
  end

  defp migrate(connection, version, statements) do
    {:ok, :migrated} =
      Exqlite.transaction(
        connection,
        fn transaction ->
          Enum.each(statements, &Exqlite.query!(transaction, &1))

          Exqlite.query!(transaction, "INSERT INTO schema_migrations(version) VALUES (?)", [
            version
          ])

          :migrated
        end,
        mode: :immediate
      )
  end
end
