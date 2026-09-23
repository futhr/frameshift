ExUnit.start()

if System.get_env("FRAMESHIFT_CONTAINER_TESTS") != "1" do
  ExUnit.configure(exclude: [container: true])
end
