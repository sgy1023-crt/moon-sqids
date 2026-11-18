///|
/// A public ID or tuple that violates the registry's policy.
pub suberror TokenError {
  MissingVersion
  UnknownVersion(String)
  MalformedToken
  TokenTooLong(Int)
  InvalidPayload(String, @sqids.CanonicalError)
  CannotEncode(String, @sqids.EncodeError)
  WrongFieldCount(Int, Int)
  FieldOutOfRange(String)
} derive(Debug)

///|
/// The profile selected by the token and its validated record key.
pub struct DecodedToken {
  version : String
  numbers : Array[Int64]
  legacy : Bool
}

///|
/// Issue a canonical token under the current profile.
pub fn Registry::encode(
  self : Registry,
  numbers : ArrayView[Int64],
) -> String raise TokenError {
  self.validate_fields(numbers)
  let version = self.manifest.current
  let payload = self.codecs[version].encode(numbers) catch {
    error => raise CannotEncode(version, error)
  }
  "\{version}~\{payload}"
}

///|
/// Route versioned tokens explicitly. Bare IDs are accepted only when the
/// manifest names their original encoder configuration.
pub fn Registry::decode(
  self : Registry,
  token : String,
) -> DecodedToken raise TokenError {
  if token.code_units().length() > self.max_token_length {
    raise TokenTooLong(self.max_token_length)
  }
  let (version, payload, legacy) = match token.split_once("~") {
    Some((tag, payload)) => {
      let version = tag.to_owned()
      if !valid_version(version) || payload.contains_char('~') {
        raise MalformedToken
      }
      (version, payload.to_owned(), false)
    }
    None =>
      match self.manifest.legacy {
        Some(version) => (version, token, true)
        None => raise MissingVersion
      }
  }
  if payload.is_empty() {
    raise MalformedToken
  }
  guard self.codecs.get(version) is Some(codec) else {
    raise UnknownVersion(version)
  }
  let numbers = codec.decode_canonical(payload) catch {
    error => raise InvalidPayload(version, error)
  }
  self.validate_fields(numbers[:])
  { version, numbers, legacy, }
}

///|
fn Registry::validate_fields(
  self : Registry,
  numbers : ArrayView[Int64],
) -> Unit raise TokenError {
  let fields = self.manifest.fields
  if fields.length() != numbers.length() {
    raise WrongFieldCount(fields.length(), numbers.length())
  }
  for index, field in fields {
    let number = numbers[index]
    if number < field.min || number > field.max {
      raise FieldOutOfRange(field.name)
    }
  }
}
