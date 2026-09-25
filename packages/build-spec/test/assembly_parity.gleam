import assembly_fixture
import frameshift_build/assembly
import gleam/io
import gleam/list

pub fn main() {
  list.each(assembly_fixture.sequences(), fn(value) {
    let assert Ok(bytes) = assembly.encode(value)
    io.print(bytes)
  })
}
