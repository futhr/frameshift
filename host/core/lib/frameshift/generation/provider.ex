defmodule Frameshift.Generation.Provider do
  @moduledoc """
  Contract for one explicitly selected still-image generation provider.

  Provider context may contain credentials or process handles. The generation
  coordinator never persists or logs that context.
  """

  @type request :: map()
  @type context :: term()
  @type result :: %{
          required(:bytes) => binary(),
          required(:width) => pos_integer(),
          required(:height) => pos_integer(),
          required(:media_type) => String.t(),
          required(:result_id) => String.t()
        }
  @type preflight :: %{
          required(:provider_id) => String.t(),
          required(:model) => String.t(),
          required(:destination) => :local | :cloud,
          required(:capabilities) => map(),
          required(:disclosures) => map()
        }

  @callback id() :: String.t()
  @callback preflight(context()) :: {:ok, preflight()} | {:error, term()}
  @callback generate(request(), context()) :: {:ok, result()} | {:error, term()}
end
