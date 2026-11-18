///|
/// A deterministic mapping for one previously issued public ID.
pub struct Mapping {
  source_id : String
  source_version : String
  target_id : String
  numbers : Array[Int64]
  changed : Bool
} derive(ToJson)

///|
/// Validate a source ID and map it to the active version. Feeding target_id
/// back into this method produces the same target with changed=false.
pub fn Registry::plan(self : Registry, id : String) -> Mapping raise TokenError {
  let source = self.decode(id)
  let target_id = if source.version == self.manifest.current && !source.legacy {
    id
  } else {
    self.encode(source.numbers[:])
  }
  {
    source_id: id,
    source_version: source.version,
    target_id,
    numbers: source.numbers,
    changed: target_id != id,
  }
}

///|
/// Stable machine-readable names for failure reasons in migration reports.
pub fn TokenError::code(self : TokenError) -> String {
  match self {
    MissingVersion => "missing_version"
    UnknownVersion(_) => "unknown_version"
    MalformedToken => "malformed_token"
    InvalidPayload(_, @sqids.InvalidId) => "invalid_payload"
    InvalidPayload(_, @sqids.NonCanonicalId) => "noncanonical_payload"
    InvalidPayload(_, @sqids.CanonicalDecodeFailure(_)) => "numeric_overflow"
    InvalidPayload(_, @sqids.CanonicalEncodeFailure(_)) =>
      "cannot_check_canonical"
    CannotEncode(_, _) => "cannot_encode"
    WrongFieldCount(_, _) => "wrong_field_count"
    FieldOutOfRange(_) => "field_out_of_range"
  }
}
