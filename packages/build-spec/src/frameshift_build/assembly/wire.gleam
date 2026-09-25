import frameshift_build/assembly/model as m
import gleam/dynamic/decode as d

pub fn assembly() -> d.Decoder(m.Assembly) {
  use class <- d.field("class", d.string)
  use connections <- d.field("connections", d.list(connection()))
  use dependencies <- d.field("dependencies", d.list(dependency()))
  use instances <- d.field("instances", d.list(instance()))
  use intent <- d.field("intent", intent())
  use schema <- d.field("schema", d.int)
  use semantics <- d.field("semantics", d.string)
  d.success(m.Assembly(
    class:,
    connections:,
    dependencies:,
    instances:,
    intent:,
    schema:,
    semantics:,
  ))
}

fn connection() -> d.Decoder(m.Connection) {
  use from <- d.field("from", endpoint())
  use to <- d.field("to", endpoint())
  d.success(m.Connection(from:, to:))
}

fn endpoint() -> d.Decoder(m.Endpoint) {
  use instance <- d.field("instance", d.string)
  use port <- d.field("port", d.string)
  d.success(m.Endpoint(instance:, port:))
}

fn dependency() -> d.Decoder(m.Dependency) {
  use consumer <- d.field("consumer", d.string)
  use provider <- d.field("provider", d.string)
  use role <- d.field("role", d.string)
  d.success(m.Dependency(consumer:, provider:, role:))
}

fn instance() -> d.Decoder(m.Instance) {
  use id <- d.field("id", d.string)
  use location <- d.field("location", d.string)
  use placement <- d.field("placement", placement())
  use profile <- d.field("profile", d.string)
  d.success(m.Instance(id:, location:, placement:, profile:))
}

fn placement() -> d.Decoder(m.Placement) {
  use rotation <- d.field("rotation", d.int)
  use x_um <- d.field("x_um", d.int)
  use y_um <- d.field("y_um", d.int)
  use z_um <- d.field("z_um", d.int)
  d.success(m.Placement(rotation:, x_um:, y_um:, z_um:))
}

fn intent() -> d.Decoder(m.Intent) {
  use ambient_mc <- d.field("ambient_mc", range())
  use artifact <- d.field("artifact", d.string)
  use dwell_ms <- d.field("dwell_ms", d.int)
  use firmware <- d.field("firmware", d.string)
  use mounting <- d.field("mounting", d.string)
  use protocol <- d.field("protocol", d.string)
  use storage_bytes <- d.field("storage_bytes", d.int)
  d.success(m.Intent(
    ambient_mc:,
    artifact:,
    dwell_ms:,
    firmware:,
    mounting:,
    protocol:,
    storage_bytes:,
  ))
}

fn range() -> d.Decoder(m.Range) {
  use high <- d.field("max", d.int)
  use low <- d.field("min", d.int)
  d.success(m.Range(low, high))
}
