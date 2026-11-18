///|
test "migration preserves semantic identity and is idempotent" {
  let registry = @migration.Registry::parse(sample_policy)
  let old = registry.plan("A6da")
  assert_eq(old.source_id, "A6da")
  assert_eq(old.source_version, "v1")
  assert_eq(old.numbers, [12345L])
  assert_true(old.changed)
  assert_eq(old.target_id, registry.encode([12345L]))
  assert_eq(registry.plan("v1~A6da").target_id, old.target_id)
  let repeated = registry.plan(old.target_id)
  assert_false(repeated.changed)
  assert_eq(repeated.source_version, "v2")
  assert_eq(repeated.target_id, old.target_id)
}

///|
test "migration reports source rejection and target encoding failure separately" {
  let registry = @migration.Registry::parse(
    (
      #|{"current":"v2","legacy":"v1","fields":[{"name":"record","min":"0","max":"10"}],"profiles":[
      #|{"version":"v1","alphabet":"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789","min_length":0,"blocklist":[]},
      #|{"version":"v2","alphabet":"abc","min_length":3,"blocklist":["cab","abc","bca"]}]}
    ),
  )
  try registry.plan("bM") catch {
    error => assert_eq(error.code(), "cannot_encode")
  } noraise {
    _ => fail("expected the current version to be blocked")
  }
  try registry.plan("bMM") catch {
    error => assert_eq(error.code(), "noncanonical_payload")
  } noraise {
    _ => fail("expected the source version to reject an alias")
  }
}
