///|
/// A failure while verifying that an ID is the one this codec would generate.
pub suberror CanonicalError {
  InvalidId
  NonCanonicalId
  CanonicalDecodeFailure(DecodeError)
  CanonicalEncodeFailure(EncodeError)
} derive(Debug)

///|
/// Decode an ID and require it to match this codec's exact encoding.
/// The empty string is the canonical encoding of an empty sequence.
/// Use decode when historical alphabets match but padding or blocklists differ.
pub fn Sqids::decode_canonical(
  self : Sqids,
  id : String,
) -> Array[Int64] raise CanonicalError {
  if id.is_empty() {
    return []
  }
  let numbers = self.decode(id) catch {
    error => raise CanonicalDecodeFailure(error)
  }
  if numbers.is_empty() {
    raise InvalidId
  }
  let canonical = self.encode(numbers[:]) catch {
    error => raise CanonicalEncodeFailure(error)
  }
  if canonical != id {
    raise NonCanonicalId
  }
  numbers
}
