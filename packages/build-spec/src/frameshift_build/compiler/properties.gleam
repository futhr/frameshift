/// Exact property semantics, independent of profile labels and vendor names.
/// Membership does not establish constraint completeness or source authenticity.
pub type Scope {
  Component
  PowerPort
  SignalPort
  MechanicalPort
}

pub type Property {
  Number(unit: String, minimum: Int)
  Terms
}

pub fn lookup(scope: Scope, key: String) -> Result(Property, Nil) {
  case scope {
    Component -> component(key)
    PowerPort -> power(key)
    SignalPort ->
      case key {
        "logic.voltage" -> Ok(Number("mv", 0))
        _ -> electrical_contract(key)
      }
    MechanicalPort ->
      case key {
        "mount.capacity" -> Ok(Number("g", 0))
        "mount.pattern" | "strain_relief.contract" -> Ok(Terms)
        _ -> Error(Nil)
      }
  }
}

pub fn unit(property: Property) -> String {
  case property {
    Number(unit, _) -> unit
    Terms -> "token"
  }
}

fn component(key: String) -> Result(Property, Nil) {
  case key {
    "outline.width"
    | "outline.height"
    | "outline.depth"
    | "active.width"
    | "active.height"
    | "inner.width"
    | "inner.height"
    | "inner.depth"
    | "opening.width"
    | "opening.height" -> Ok(Number("um", 1))
    "active.offset.x"
    | "active.offset.y"
    | "opening.x"
    | "opening.y"
    | "clearance.left"
    | "clearance.right"
    | "clearance.top"
    | "clearance.bottom"
    | "clearance.front"
    | "clearance.back"
    | "connector.clearance"
    | "cable.clearance" -> Ok(Number("um", 0))
    "mass" | "mount.capacity" -> Ok(Number("g", 0))
    "power.maximum"
    | "power.output_capacity"
    | "heat.maximum"
    | "thermal.capacity" -> Ok(Number("mw", 0))
    "temperature.operating" | "thermal.ambient" -> Ok(Number("mc", -100_000))
    "storage.capacity" -> Ok(Number("byte", 0))
    "refresh.minimum"
    | "refresh.maximum"
    | "refresh.recommended_minimum"
    | "refresh.recommended_maximum"
    | "refresh.energy_recommended" -> Ok(Number("ms", 0))
    "raster.width" | "raster.height" -> Ok(Number("count", 1))
    "artifact.contract"
    | "firmware.contract"
    | "protocol.contract"
    | "assembly.thermal"
    | "mount.pattern"
    | "mount.kind"
    | "power.mode" -> Ok(Terms)
    _ -> Error(Nil)
  }
}

fn power(key: String) -> Result(Property, Nil) {
  case key {
    "input.voltage" | "output.voltage" | "voltage.drop" -> Ok(Number("mv", 0))
    "current.maximum" | "current.capacity" -> Ok(Number("ma", 0))
    "power.maximum" | "power.capacity" -> Ok(Number("mw", 0))
    "fanout.maximum" -> Ok(Number("count", 0))
    _ -> electrical_contract(key)
  }
}

fn electrical_contract(key: String) -> Result(Property, Nil) {
  case key {
    "polarity"
    | "reference.contract"
    | "pinout.contract"
    | "connector.contract"
    | "protection.contract"
    | "driver.contract"
    | "interface.family"
    | "strain_relief.contract" -> Ok(Terms)
    _ -> Error(Nil)
  }
}
