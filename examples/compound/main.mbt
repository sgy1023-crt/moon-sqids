///|
fn main raise {
  let codec = @sqids.Sqids::new()
  let id = codec.encode([7L, 3L, 12345L])
  guard codec.decode(id) is [tenant, partition, record] else {
    fail("expected a tenant, partition and record")
  }
  println("/records?locator=\{id}")
  println("[tenant, partition, record] = [\{tenant}, \{partition}, \{record}]")
}
