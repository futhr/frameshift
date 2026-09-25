/// Explicit pixel assignments. These constructors do not validate layout bytes
/// or qualify a runtime's execution of the intended assignment.
pub type Document {
  Document(
    artifact: String,
    controller: String,
    encoding: String,
    firmware: String,
    height: Int,
    protocol: String,
    schema: Int,
    tiles: List(Tile),
    width: Int,
  )
}

pub type Tile {
  Tile(display: String, rotation: Int, x: Int, y: Int)
}
