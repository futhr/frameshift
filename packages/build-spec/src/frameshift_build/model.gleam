/// Immutable component facts. Constructors alone are not admission; external
/// boundaries must use the validated profile codec.
pub type Profile {
  Profile(
    classes: List(String),
    facts: List(Fact),
    id: String,
    kind: String,
    manufacturer: String,
    part: String,
    part_revision: String,
    ports: List(Port),
    requires: List(String),
    revision: String,
    schema: Int,
  )
}

pub type Port {
  Port(
    direction: String,
    facts: List(Fact),
    id: String,
    kind: String,
    required: Bool,
  )
}

pub type Fact {
  Fact(key: String, sources: List(Source), unit: String, value: Value)
}

pub type Source {
  Source(digest: String, evidence: String, locator: String, revision: String)
}

pub type Value {
  KnownRange(minimum: Int, maximum: Int)
  KnownTerms(terms: List(String))
  Missing
  Conflicting
}

pub type Refusal {
  TooLarge
  TooDeep
  InvalidDocument
  UnsupportedVersion
  InvalidIdentifier
  InvalidEnum
  InvalidRange
  InvalidCount
  DuplicateIdentifier
  InvalidSource
  InvalidFact
  NonCanonical
  InvalidIdentity
  InvalidReference
  UnsupportedSemantics
  UnreferencedProfile
}
