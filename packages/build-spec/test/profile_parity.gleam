import frameshift_build
import gleam/io
import gleam/list
import gleam/string
import profile_fixture

pub fn main() {
  list.each(profile_fixture.sequences(), fn(profile) {
    let assert Ok(bytes) = frameshift_build.encode(profile)
    io.println(string.trim_end(bytes))
  })
}
