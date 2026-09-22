defmodule Frameshift.Protocol.ThingTest do
  use ExUnit.Case, async: true

  alias Frameshift.Protocol.Thing
  alias Wotex.Runtime.{BindingProfile, Error, Selection}
  alias Wotex.{ThingDescription, ThingModel}

  @fixtures_dir Path.expand("../../../../../protocol/fixtures/valid", __DIR__)

  test "embedded Frame and Host Outbox Thing Models pass bounded W3C validation" do
    assert {:ok, frame} = Thing.model(:frame)
    assert {:ok, outbox} = Thing.model(:host_outbox)

    assert ThingModel.id(frame) == "urn:frameshift:model:frame:0.1"
    assert ThingModel.to_map(frame)["frameshift:profile"] == Thing.frame_profile()

    assert ThingModel.id(outbox) == "urn:frameshift:model:host-outbox:0.1"
    assert ThingModel.to_map(outbox)["frameshift:profile"] == Thing.host_outbox_profile()
  end

  test "admits the complete frame role and preserves unknown extensions" do
    source = frame_source()
    document = Jason.decode!(source)
    extended = Map.put(document, "vendor:diagnosticHint", %{"mode" => "bounded"})

    assert {:ok, td} = extended |> Jason.encode!() |> Thing.parse_frame()
    assert ThingDescription.to_map(td)["vendor:diagnosticHint"] == %{"mode" => "bounded"}
  end

  test "admits the Host Outbox role independently of frame hardware" do
    assert {:ok, td} = Thing.parse_host_outbox(outbox_source())
    assert ThingDescription.id(td) == "urn:frameshift:host:simulated-outbox-0001"
  end

  test "selects the advertised Form and resolves its relative href" do
    assert {:ok, td} = Thing.parse_frame(frame_source())
    assert {:ok, profile} = Thing.reference_https_profile()

    assert {:ok, %Selection{} = selection} =
             Thing.select_frame(td, :property, "state", :readproperty, [profile])

    assert selection.resolved_href == "https://frame.invalid/v0/state"
    assert selection.profile.id == :frameshift_https_json_v0_1
    assert selection.security.names == ["mtls"]
  end

  test "endpoint changes do not create vendor or route branches" do
    source = frame_source()

    changed =
      source
      |> Jason.decode!()
      |> Map.put("base", "https://other-frame.invalid/root/")
      |> put_in(["properties", "state", "forms", Access.at(0), "href"], "status/current")
      |> Jason.encode!()

    assert {:ok, td} = Thing.parse_frame(changed)
    assert {:ok, profile} = Thing.reference_https_profile()

    assert {:ok, selection} =
             Thing.select_frame(td, :property, "state", :readproperty, [profile])

    assert selection.resolved_href == "https://other-frame.invalid/root/status/current"
  end

  test "caller profile capability, not a fallback route, controls compatibility" do
    assert {:ok, td} = Thing.parse_frame(frame_source())

    assert {:ok, mqtt_only} =
             BindingProfile.new(
               id: :mqtt_only,
               schemes: ["mqtts"],
               operations: [:readproperty],
               media_types: ["application/json"]
             )

    assert {:error, %Error{code: :compatible_form_not_found}} =
             Thing.select_frame(td, :property, "state", :readproperty, [mqtt_only])
  end

  test "binary artifact selection requires the exact advertised media type" do
    assert {:ok, td} = Thing.parse_frame(frame_source())
    assert {:ok, json_profile} = Thing.reference_https_profile()

    assert {:error, %Error{code: :compatible_form_not_found}} =
             Thing.select_frame(td, :action, "installAsset", :invokeaction, [json_profile])

    assert {:ok, artifact_profile} =
             Thing.reference_https_artifact_profile([
               "application/vnd.frameshift.rgb24"
             ])

    assert {:ok, selection} =
             Thing.select_frame(td, :action, "installAsset", :invokeaction, [artifact_profile])

    assert selection.resolved_href == "https://frame.invalid/v0/assets/sha256/{digest}"
    assert selection.profile.id == :frameshift_https_artifact_v0_1
  end

  test "rejects unknown required profiles before Form selection" do
    invalid =
      frame_source()
      |> Jason.decode!()
      |> Map.update!("profile", &(&1 ++ ["urn:frameshift:profile:vendor-private:9"]))
      |> Jason.encode!()

    assert {:error, %Thing.Error{code: :unsupported_required_profile, path: "/profile"}} =
             Thing.parse_frame(invalid)
  end

  test "rejects missing universal affordances and invalid capabilities" do
    missing =
      frame_source()
      |> Jason.decode!()
      |> update_in(["actions"], &Map.delete(&1, "setDesired"))
      |> Jason.encode!()

    assert {:error,
            %Thing.Error{
              code: :required_affordance_missing,
              path: "/actions/setDesired"
            }} = Thing.parse_frame(missing)

    invalid_capabilities =
      frame_source()
      |> Jason.decode!()
      |> put_in(["frameshift:capabilities", "stillOnly"], false)
      |> Jason.encode!()

    assert {:error, %Thing.Error{code: :frame_overlay_invalid}} =
             Thing.parse_frame(invalid_capabilities)
  end

  test "bounded admission rejects duplicate members and oversized TDs" do
    duplicate =
      String.replace(
        frame_source(),
        ~S("title": "Frameshift simulated photo frame",),
        ~S("title": "first", "title": "second",)
      )

    assert {:error, %Wotex.Error{code: :duplicate_member, path: "/title"}} =
             Thing.parse_frame(duplicate)

    oversized_extension = String.duplicate("x", 262_144)

    oversized =
      frame_source()
      |> Jason.decode!()
      |> Map.put("vendor:oversized", oversized_extension)
      |> Jason.encode!()

    assert {:error, %Wotex.Error{code: :byte_limit_exceeded}} = Thing.parse_frame(oversized)
  end

  test "a remote extension context is preserved without becoming a required profile" do
    source =
      frame_source()
      |> Jason.decode!()
      |> Map.update!("@context", &(&1 ++ ["https://unreachable.invalid/context.jsonld"]))
      |> Jason.encode!()

    assert {:ok, td} = Thing.parse_frame(source)

    assert List.last(ThingDescription.to_map(td)["@context"]) ==
             "https://unreachable.invalid/context.jsonld"
  end

  defp frame_source, do: File.read!(Path.join(@fixtures_dir, "thing-description.json"))

  defp outbox_source,
    do: File.read!(Path.join(@fixtures_dir, "host-outbox-thing-description.json"))
end
