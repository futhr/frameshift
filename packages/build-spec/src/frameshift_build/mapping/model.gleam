/// Immutable sourced route declarations. Identity and catalog admission remain
/// separate; constructors alone do not validate documents or physical ports.
import frameshift_build/model.{type Source}

pub type Document {
  Document(
    artifact: String,
    firmware: String,
    pairs: List(Pair),
    profile: String,
    protocol: String,
    schema: Int,
    sources: List(Source),
  )
}

pub type Pair {
  Pair(input: String, output: String)
}
