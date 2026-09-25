[path | options] = System.argv()

identity =
  case options do
    ["assembly"] -> &FrameshiftBuild.build_identity/1
    ["mapping"] -> &FrameshiftBuild.mapping_identity/1
    ["layout"] -> &FrameshiftBuild.layout_identity/1
    _ -> &FrameshiftBuild.profile_identity/1
  end

Enum.each(File.stream!(path), fn bytes ->
  {:ok, value} = identity.(bytes)
  IO.puts(value)
end)
