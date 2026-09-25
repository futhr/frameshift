import frameshift_build/assembly/model as m
import gleam/json as j
import gleam/list
import gleam/string

// Internal encoding; the public assembly codec validates before using it.
pub fn assembly(value: m.Assembly) -> String {
  j.object([
    #("class", j.string(value.class)),
    #("connections", sorted(value.connections, connection)),
    #("dependencies", sorted(value.dependencies, dependency)),
    #(
      "instances",
      j.array(
        list.sort(value.instances, fn(a, b) { string.compare(a.id, b.id) }),
        instance,
      ),
    ),
    #("intent", intent(value.intent)),
    #("schema", j.int(value.schema)),
    #("semantics", j.string(value.semantics)),
  ])
  |> j.to_string
  |> string.append("\n")
}

fn sorted(values: List(a), encode: fn(a) -> j.Json) -> j.Json {
  values
  |> list.sort(fn(a, b) {
    string.compare(encode(a) |> j.to_string, encode(b) |> j.to_string)
  })
  |> j.array(encode)
}

pub fn connection_key(value: m.Connection) -> String {
  connection(value) |> j.to_string
}

pub fn dependency_key(value: m.Dependency) -> String {
  dependency(value) |> j.to_string
}

fn connection(value: m.Connection) -> j.Json {
  j.object([#("from", endpoint(value.from)), #("to", endpoint(value.to))])
}

fn endpoint(value: m.Endpoint) -> j.Json {
  j.object([
    #("instance", j.string(value.instance)),
    #("port", j.string(value.port)),
  ])
}

fn dependency(value: m.Dependency) -> j.Json {
  j.object([
    #("consumer", j.string(value.consumer)),
    #("provider", j.string(value.provider)),
    #("role", j.string(value.role)),
  ])
}

fn instance(value: m.Instance) -> j.Json {
  j.object([
    #("id", j.string(value.id)),
    #("location", j.string(value.location)),
    #("placement", placement(value.placement)),
    #("profile", j.string(value.profile)),
  ])
}

fn placement(value: m.Placement) -> j.Json {
  j.object([
    #("rotation", j.int(value.rotation)),
    #("x_um", j.int(value.x_um)),
    #("y_um", j.int(value.y_um)),
    #("z_um", j.int(value.z_um)),
  ])
}

fn intent(value: m.Intent) -> j.Json {
  j.object([
    #(
      "ambient_mc",
      j.object([
        #("max", j.int(value.ambient_mc.maximum)),
        #("min", j.int(value.ambient_mc.minimum)),
      ]),
    ),
    #("artifact", j.string(value.artifact)),
    #("dwell_ms", j.int(value.dwell_ms)),
    #("firmware", j.string(value.firmware)),
    #("mounting", j.string(value.mounting)),
    #("protocol", j.string(value.protocol)),
    #("storage_bytes", j.int(value.storage_bytes)),
  ])
}
