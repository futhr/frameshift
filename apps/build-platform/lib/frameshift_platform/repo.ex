defmodule FrameshiftPlatform.Repo do
  @moduledoc "PostgreSQL owner for Frameshift commercial domain records."

  use AshPostgres.Repo, otp_app: :frameshift_platform

  @impl true
  def installed_extensions, do: ["ash-functions"]

  @impl true
  def min_pg_version, do: %Version{major: 18, minor: 0, patch: 0}
end
