defmodule Frameshift.DisplayTimingTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.DisplayTiming
  alias Frameshift.Protocol.Schema

  @fixture Path.expand("../../../../protocol/fixtures/valid/capabilities-photo.json", __DIR__)

  test "a qualified suggestion retains its basis and respects the minimum" do
    capability =
      @fixture
      |> File.read!()
      |> JSON.decode!()
      |> put_in(["refresh", "recommendedDwellMs"], 21_600_000)
      |> put_in(["refresh", "recommendationBasis"], "provisional-profile")
      |> put_in(["refresh", "recommendationRevision"], "frameshift-paper-e6-v1")

    assert :ok = Schema.validate("capabilities", capability)

    assert DisplayTiming.recommendation(capability) == %{
             dwell_ms: 21_600_000,
             basis: "provisional-profile",
             revision: "frameshift-paper-e6-v1"
           }

    assert DisplayTiming.clamp_dwell(capability, 1) == 1_000
    assert DisplayTiming.clamp_dwell(capability, 3_000) == 3_000
  end

  test "incomplete and shorter-than-minimum suggestions are rejected" do
    capability = @fixture |> File.read!() |> JSON.decode!()
    incomplete = put_in(capability, ["refresh", "recommendedDwellMs"], 2_000)
    assert {:error, %JSV.ValidationError{}} = Schema.validate("capabilities", incomplete)

    too_short =
      incomplete
      |> put_in(["refresh", "recommendedDwellMs"], 999)
      |> put_in(["refresh", "recommendationBasis"], "measured-energy")
      |> put_in(["refresh", "recommendationRevision"], "bench-v1")

    assert {:error, :recommendation_below_minimum} =
             Schema.validate("capabilities", too_short)
  end

  test "continuous display has no energy suggestion without measured evidence" do
    capability = @fixture |> File.read!() |> JSON.decode!()
    assert :ok = Schema.validate("capabilities", capability)
    assert DisplayTiming.recommendation(capability) == nil
  end
end
