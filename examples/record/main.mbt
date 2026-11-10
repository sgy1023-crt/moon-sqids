///|
fn main raise {
  let codec = @sqids.Sqids::new()
  let id = codec.encode([12345L])
  guard codec.decode(id) is [record] else { fail("expected one record number") }
  println("Record 12345 -> \{id} -> \{record}")
}
