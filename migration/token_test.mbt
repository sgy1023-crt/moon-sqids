///|
let sample_policy : String =
  #|{"current":"v2","legacy":"v1","fields":[{"name":"record","min":"1","max":"9007199254740991"}],
  #|"profiles":[
  #|{"version":"v1","alphabet":"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789","min_length":0,"blocklist":[]},
  #|{"version":"v2","alphabet":"FxnXM1kBN6cuhsAvjW3Co7l2RePyY8DwaU04Tzt9fHQrqSVKdpimLGIJOgb5ZE","min_length":10,"blocklist":[]}]}

///|
test "a different alphabet preserves the old record key" {
  let registry = @migration.Registry::parse(sample_policy)
  let new_token = registry.encode([12345L])
  assert_true(new_token.has_prefix("v2~"))
  let old = registry.decode("A6da")
  assert_eq(old.version, "v1")
  assert_true(old.legacy)
  assert_eq(old.numbers, [12345L])
  assert_eq(registry.decode("v1~A6da").numbers, old.numbers)
  assert_eq(registry.decode(new_token).numbers, old.numbers)
  assert_eq(registry.decode(registry.encode([9007199254740991L])).numbers, [
    9007199254740991L,
  ])
}

///|
test "bad versions, aliases and malformed separators cannot fall back to v1" {
  let registry = @migration.Registry::parse(sample_policy)
  for id in ["~A6da", "v1~", "v1~A6da~again", "V1~A6da"] {
    try registry.decode(id) catch {
      @migration.MalformedToken => ()
      error => raise error
    } noraise {
      _ => fail("expected malformed token")
    }
  }
  try registry.decode("v3~A6da") catch {
    @migration.UnknownVersion(version) => assert_eq(version, "v3")
    error => raise error
  } noraise {
    _ => fail("expected unknown version")
  }
  try registry.decode("v1~bMM") catch {
    @migration.InvalidPayload(version, _) => assert_eq(version, "v1")
    error => raise error
  } noraise {
    _ => fail("expected invalid payload")
  }
}

///|
test "business constraints are enforced on writes and legacy reads" {
  let registry = @migration.Registry::parse(sample_policy)
  try registry.encode([1L, 2L]) catch {
    @migration.WrongFieldCount(expected, actual) => {
      assert_eq(expected, 1)
      assert_eq(actual, 2)
    }
    error => raise error
  } noraise {
    _ => fail("expected a field count error")
  }
  for id in ["bM", "v1~bM"] {
    try registry.decode(id) catch {
      @migration.FieldOutOfRange(field) => assert_eq(field, "record")
      error => raise error
    } noraise {
      _ => fail("expected a field range error")
    }
  }
}

///|
test "unsafe alphabets and missing references fail during configuration" {
  let unsafe_policy = sample_policy.replace_all(
    old="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    new="abc~",
  )
  try @migration.Registry::parse(unsafe_policy) catch {
    @migration.UnsafeAlphabet(version) => assert_eq(version, "v1")
    error => raise error
  } noraise {
    _ => fail("expected an unsafe alphabet")
  }
  let missing = sample_policy.replace_all(
    old="\"legacy\":\"v1\"",
    new="\"legacy\":\"v9\"",
  )
  try @migration.Registry::parse(missing) catch {
    @migration.UnconfiguredVersion(version) => assert_eq(version, "v9")
    error => raise error
  } noraise {
    _ => fail("expected an unconfigured version")
  }
}
