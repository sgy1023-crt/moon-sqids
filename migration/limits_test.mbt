///|
test "payload size budget covers max safe numbers and padding" {
  let registry = @migration.Registry::parse(
    (
      #|{"current":"v2","fields":[{"name":"record","min":"0","max":"9007199254740991"}],"profiles":[
      #|{"version":"v2","alphabet":"abc","min_length":255,"blocklist":[]}]}
    ),
  )
  let id = registry.encode([9007199254740991L])
  assert_eq(id.code_units().length(), 258)
  assert_eq(registry.decode(id).numbers, [9007199254740991L])
  try registry.decode(id + "a") catch {
    @migration.TokenTooLong(limit) => assert_eq(limit, 258)
    error => raise error
  } noraise {
    _ => fail("oversized token must be rejected before decoding")
  }
}
