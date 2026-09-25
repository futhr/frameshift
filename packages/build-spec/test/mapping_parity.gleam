import frameshift_build/mapping
import gleam/int
import gleam/io
import gleam/string
import mapping_fixture

pub fn main() {
  int.range(0, 256, Nil, fn(_, seed) {
    let assert Ok(bytes) = mapping.encode(mapping_fixture.document(seed))
    io.println(string.trim_end(bytes))
  })
}
