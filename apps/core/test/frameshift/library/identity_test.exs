defmodule Frameshift.Library.IdentityTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Digest
  alias Frameshift.Library.Identity

  test "master admission checks source kind before a storage effect" do
    attributes = %{
      title: "Study",
      source_kind: :import,
      width: 12,
      height: 8,
      media_type: "image/png",
      provenance: %{}
    }

    assert :ok = Identity.validate_master(attributes, nil, nil)

    assert {:error, :invalid_master_relationship} =
             Identity.validate_master(attributes, Digest.sha256("parent"), nil)

    assert {:error, :invalid_width} =
             Identity.validate_master(%{attributes | width: 0}, nil, nil)

    assert :ok =
             Identity.validate_master(
               %{attributes | source_kind: :generated},
               nil,
               Digest.sha256("recipe")
             )
  end

  test "recipe identity ignores parameter insertion order but preserves source order" do
    first = Digest.sha256("first")
    second = Digest.sha256("second")
    assert :ok = Identity.validate_recipe_input(:composition, %{}, [first, second])

    assert {:ok, hash, "composition", canonical_json} =
             Identity.recipe_identity(:composition, %{"b" => 2, "a" => 1}, [first, second])

    assert {:ok, ^hash, "composition", ^canonical_json} =
             Identity.recipe_identity(:composition, %{"a" => 1, "b" => 2}, [first, second])

    assert {:ok, other_hash, _, _} =
             Identity.recipe_identity(:composition, %{"a" => 1, "b" => 2}, [second, first])

    refute hash == other_hash

    assert {:error, :invalid_source_digest} =
             Identity.validate_recipe_input(:composition, %{}, ["bad"])
  end
end
