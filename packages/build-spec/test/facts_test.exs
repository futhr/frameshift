defmodule FrameshiftBuild.FactsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @data Path.expand("../../../data/physical", __DIR__)
  @manifest @data |> Path.join("manifest.json") |> File.read!() |> :json.decode()
  @plan File.read!(Path.join(__DIR__, "fixtures/assembly-v1.json"))

  test "actual baseline profiles retain missing bounds despite nearby quoted values" do
    cases = [
      {"waveshare-13.3-e6-panel", ["outline.depth", "refresh.energy_recommended"]},
      {"boe-mv270qhm-n40-p1", ["outline.width", "power.maximum", "temperature.operating"]},
      {"waveshare-p3-64x64-22100", ["outline.width", "power.maximum"]}
    ]

    for {id, keys} <- cases do
      {instance, resolution} = resolve(id)
      assert Enum.all?(keys, &(reading(instance, &1, resolution) == {:missing_fact, []}))
    end
  end

  test "Paper operating conflict keeps both exact citations on the BEAM adapter path" do
    {instance, resolution} = resolve("waveshare-13.3-e6-panel")

    assert {:conflicting_fact, [first, second]} =
             reading(instance, "temperature.operating", resolution)

    refute first == second
    assert {:usable, [_]} = reading(instance, "active.width", resolution)
  end

  defp resolve(id) do
    entry = Enum.find(@manifest["profiles"], &(&1["id"] == id))
    body = @data |> Path.join(entry["file"]) |> File.read!()

    plan =
      @plan
      |> String.replace("sha256:" <> String.duplicate("a", 64), entry["identity"])
      |> String.replace("sha256:" <> String.duplicate("b", 64), entry["identity"])

    {:ok, %{resolution: resolution}} = FrameshiftBuild.resolve_build(plan, [body])
    {:resolution, {:assembly, _, _, _, [instance | _], _, _, _}, _, _} = resolution
    {instance, resolution}
  end

  defp reading(instance, key, resolution) do
    {:reading, _, _, _, _, _, _, _, sources, status} =
      :frameshift_build@compiler@facts.component(instance, key, resolution)

    {status, sources}
  end
end
