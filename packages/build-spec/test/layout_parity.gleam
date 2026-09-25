import frameshift_build/artifact
import gleam/int
import gleam/io
import gleam/string
import layout_fixture

pub fn main() {
  int.range(0, 256, Nil, fn(_, seed) {
    let assert Ok(bytes) = artifact.encode(layout_fixture.document(seed))
    io.println(string.trim_end(bytes))
  })
}
