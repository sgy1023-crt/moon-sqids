///|
test "manifest JSON rejects typos in the bare link policy and fractional lengths" {
  let typo = sample_policy.replace_all(old="\"legacy\"", new="\"legcay\"")
  try @migration.Registry::parse(typo) catch {
    @migration.UnknownManifestKey(location, key) => {
      assert_eq(location, "manifest")
      assert_eq(key, "legcay")
    }
    error => raise error
  } noraise {
    _ => fail("expected a misspelled key to be rejected")
  }
  let fractional = sample_policy.replace_all(
    old="\"min_length\":10",
    new="\"min_length\":10.5",
  )
  try @migration.Registry::parse(fractional) catch {
    @migration.InvalidProfileLength(index) => assert_eq(index, 1)
    error => raise error
  } noraise {
    _ => fail("expected a fractional length to be rejected")
  }
}

///|
test "composite business keys preserve field order and reject the wrong shape" {
  let composite = sample_policy.replace_all(
    old="\"fields\":[{\"name\":\"record\"",
    new="\"fields\":[{\"name\":\"tenant\",\"min\":\"1\",\"max\":\"10\"},{\"name\":\"shard\",\"min\":\"0\",\"max\":\"9\"},{\"name\":\"record\"",
  )
  let registry = @migration.Registry::parse(composite)
  let migration = registry.plan("RMeyNPxf")
  assert_eq(registry.decode(migration.target_id).numbers, [7L, 3L, 12345L])
  try registry.encode([7L, 10L, 12345L]) catch {
    @migration.FieldOutOfRange(name) => assert_eq(name, "shard")
    error => raise error
  } noraise {
    _ => fail("expected the shard constraint to reject the tuple")
  }
}
