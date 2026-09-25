Enum.each(File.stream!(hd(System.argv())), fn bytes ->
  {:ok, identity} = FrameshiftBuild.profile_identity(bytes)
  IO.puts(identity)
end)
