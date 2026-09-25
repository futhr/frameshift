defmodule FrameshiftPlatform.Repo do
  @moduledoc "PostgreSQL owner for Frameshift commercial domain records."

  use AshPostgres.Repo, otp_app: :frameshift_platform

  @impl true
  def default_options(_), do: [prefix: "public"]

  @impl true
  def init(type, config) do
    {:ok, config} = super(type, config)

    {:ok,
     Keyword.put(
       config,
       :after_connect,
       {Postgrex, :query!, ["SET search_path TO public, refpath", []]}
     )}
  end

  @impl true
  def installed_extensions, do: ["ash-functions"]

  @impl true
  def min_pg_version, do: %Version{major: 18, minor: 0, patch: 0}
end
