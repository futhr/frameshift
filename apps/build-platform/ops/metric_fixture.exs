{:ok, _} = Application.ensure_all_started(:telemetry)
{:ok, _} = Application.ensure_all_started(:prometheus)
{:ok, _} = FrameshiftPlatform.Telemetry.Reporter.start_link([])

conn = %{Plug.Test.conn(:get, "/api/sources") | status: 200}
duration = System.convert_time_unit(20, :millisecond, :native)

:telemetry.execute([:frameshift_platform, :endpoint, :stop], %{duration: duration}, %{conn: conn})

:telemetry.execute([:frameshift_platform, :catalog, :source, :stop], %{count: 1}, %{outcome: :ok})

:telemetry.execute([:frameshift_platform, :repo, :query], %{
  total_time: duration,
  queue_time: duration
})

{:ok, text} = FrameshiftPlatform.Telemetry.Reporter.scrape()
IO.write(text)
