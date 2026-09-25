defmodule Frameshift do
  @moduledoc """
  The durable orchestration core for the Frameshift macOS host.

  Apple-only presentation and system APIs belong to the Swift shell. Native
  raster transforms belong to the supervised Zig worker. This application
  owns durable domain state and protocol orchestration.
  """

  @type digest :: String.t()
  @type frame_id :: String.t()
  @type profile_id :: String.t()
end
