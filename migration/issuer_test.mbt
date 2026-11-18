///|
test "a writer cannot switch until readers have the new profile" {
  let original = @migration.Registry::parse(
    (
      #|{"current":"v1","legacy":"v1","fields":[{"name":"record","min":"1","max":"9007199254740991"}],
      #|"profiles":[{"version":"v1","alphabet":"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789","min_length":0,"blocklist":[]}]}
    ),
  )
  let staged = @migration.Registry::parse(
    sample_policy.replace_all(
      old="\"current\":\"v2\"",
      new="\"current\":\"v1\"",
    ),
  )
  let writer = @migration.Registry::parse(sample_policy)
  original.check_upgrade(staged)
  try original.check_issuer(writer) catch {
    @migration.ReadersMissingVersion(version) => assert_eq(version, "v2")
    error => raise error
  } noraise {
    _ => fail("cannot issue a version unknown to deployed readers")
  }
  staged.check_issuer(writer)
  writer.check_issuer(staged)
  assert_eq(staged.decode(writer.encode([12345L])).numbers, [12345L])
}
