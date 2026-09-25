[path | options] = System.argv()

identity =
  if options == ["assembly"],
    do: &FrameshiftBuild.build_identity/1,
    else: &FrameshiftBuild.profile_identity/1

Enum.each(File.stream!(path), fn bytes ->
  {:ok, value} = identity.(bytes)
  IO.puts(value)
end)
