///|
test "reader-first deployment and issuer rollback preserve links" {
  let staged = @migration.Registry::parse(
    sample_policy.replace_all(
      old="\"current\":\"v2\"",
      new="\"current\":\"v1\"",
    ),
  )
  let active = @migration.Registry::parse(sample_policy)
  staged.check_upgrade(active)
  active.check_upgrade(staged)
  assert_eq(staged.encode([12345L]), "v1~A6da")
  let issued = active.encode([12345L])
  assert_eq(staged.decode(issued).numbers, [12345L])
  assert_eq(active.decode("A6da").numbers, [12345L])
}

///|
test "an upgrade cannot change an existing encoder" {
  let active = @migration.Registry::parse(sample_policy)
  let candidate = @migration.Registry::parse(
    sample_policy.replace_all(old="\"min_length\":10", new="\"min_length\":11"),
  )
  try active.check_upgrade(candidate) catch {
    @migration.ChangedVersion(version) => assert_eq(version, "v2")
    error => raise error
  } noraise {
    _ => fail("expected a changed historical profile to be rejected")
  }
}

///|
test "an upgrade cannot remove any profile or reassign bare links" {
  let active = @migration.Registry::parse(sample_policy)
  let reassigned = @migration.Registry::parse(
    sample_policy.replace_all(old="\"legacy\":\"v1\"", new="\"legacy\":\"v2\""),
  )
  try active.check_upgrade(reassigned) catch {
    @migration.ChangedLegacyVersion => ()
    error => raise error
  } noraise {
    _ => fail("expected reassignment to be rejected")
  }
  let removed = @migration.Registry::parse(
    (
      #|{"current":"v1","legacy":"v1","fields":[{"name":"record","min":"1","max":"9007199254740991"}],
      #|"profiles":[{"version":"v1","alphabet":"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789","min_length":0,"blocklist":[]}]}
    ),
  )
  try active.check_upgrade(removed) catch {
    @migration.RemovedVersion(version) => assert_eq(version, "v2")
    error => raise error
  } noraise {
    _ => fail("expected removal to be rejected")
  }
}

///|
test "a registry keeps an independent snapshot of caller-owned arrays" {
  let profiles : Array[@migration.Profile] = [
    { version: "v1", alphabet: "abc", min_length: 0, blocklist: ["cab"], },
  ]
  let fields : Array[@migration.Field] = [
    { name: "record", min: 1L, max: 99L, },
  ]
  let manifest : @migration.Manifest = {
    current: "v1",
    legacy: None,
    fields,
    profiles,
  }
  let previous = @migration.Registry::new(manifest)
  profiles[0].blocklist[0] = "abc"
  let changed = @migration.Registry::new(manifest)
  try previous.check_upgrade(changed) catch {
    @migration.ChangedVersion(version) => assert_eq(version, "v1")
    error => raise error
  } noraise {
    _ => fail("expected a blocklist change")
  }
  fields[0] = { name: "record", min: 2L, max: 99L, }
  let changed_fields = @migration.Registry::new(manifest)
  try previous.check_upgrade(changed_fields) catch {
    @migration.ChangedFields => ()
    error => raise error
  } noraise {
    _ => fail("expected a field change")
  }
  assert_eq(previous.decode(previous.encode([1L])).numbers, [1L])
}
