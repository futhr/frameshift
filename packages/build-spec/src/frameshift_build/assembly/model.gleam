/// Immutable planning inputs. Construction and structural validity do not grant
/// compatibility; profile resolution and the constraint compiler remain separate.
pub type Assembly {
  Assembly(
    class: String,
    connections: List(Connection),
    dependencies: List(Dependency),
    instances: List(Instance),
    intent: Intent,
    schema: Int,
    semantics: String,
  )
}

pub type Instance {
  Instance(id: String, location: String, placement: Placement, profile: String)
}

pub type Placement {
  Placement(rotation: Int, x_um: Int, y_um: Int, z_um: Int)
}

pub type Connection {
  Connection(from: Endpoint, to: Endpoint)
}

pub type Endpoint {
  Endpoint(instance: String, port: String)
}

pub type Dependency {
  Dependency(consumer: String, provider: String, role: String)
}

pub type Intent {
  Intent(
    ambient_mc: Range,
    artifact: String,
    dwell_ms: Int,
    firmware: String,
    mounting: String,
    protocol: String,
    storage_bytes: Int,
  )
}

pub type Range {
  Range(minimum: Int, maximum: Int)
}
