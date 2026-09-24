defmodule Frameshift.DisplayTiming do
  @moduledoc """
  Pure timing decisions for still-image playlists.

  A recommendation is advisory and source qualified. The minimum remains a
  hard receiver limit. The same rules apply to every display class.
  """

  @type recommendation :: %{
          dwell_ms: pos_integer(),
          basis: String.t(),
          revision: String.t()
        }

  @doc "Checks the semantic bound that JSON Schema cannot compare across fields."
  @spec validate_refresh(map()) :: :ok | {:error, :recommendation_below_minimum}
  def validate_refresh(%{"minimumDwellMs" => minimum} = refresh) do
    case Map.fetch(refresh, "recommendedDwellMs") do
      {:ok, dwell} when dwell < minimum -> {:error, :recommendation_below_minimum}
      _ -> :ok
    end
  end

  @doc "Returns the optional profile suggestion with its provenance."
  @spec recommendation(map()) :: recommendation() | nil
  def recommendation(%{"refresh" => refresh}) do
    case refresh do
      %{
        "recommendedDwellMs" => dwell,
        "recommendationBasis" => basis,
        "recommendationRevision" => revision
      } ->
        %{dwell_ms: dwell, basis: basis, revision: revision}

      _ ->
        nil
    end
  end

  @doc "Clamps an operator's dwell to the receiver's current minimum."
  @spec clamp_dwell(map(), pos_integer()) :: pos_integer()
  def clamp_dwell(%{"refresh" => %{"minimumDwellMs" => minimum}}, requested)
      when is_integer(requested) and requested > 0 do
    case :frameshift_decisions.select_dwell(minimum, requested) do
      {:ok, dwell} -> dwell
      {:error, :invalid_input} -> raise ArgumentError, "invalid dwell interval"
    end
  end
end
