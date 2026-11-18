///|
test "canonical decode round trips the empty sequence and exact IDs" {
  let codec = @moon-sqids.Sqids::new(min_length=9)
  assert_eq(codec.decode_canonical(""), [])
  let id = codec.encode([0L, @moon-sqids.max_number])
  assert_eq(codec.decode_canonical(id), [0L, @moon-sqids.max_number])
}

///|
test "canonical decode distinguishes invalid IDs from valid aliases" {
  let codec = @moon-sqids.Sqids::new(blocklist=[])
  for id in ["*", "b"] {
    try codec.decode_canonical(id) catch {
      @moon-sqids.InvalidId => ()
      error => raise error
    } noraise {
      _ => fail("expected an invalid ID")
    }
  }
  assert_eq(codec.decode("bMM"), [0L])
  try codec.decode_canonical("bMM") catch {
    @moon-sqids.NonCanonicalId => ()
    error => raise error
  } noraise {
    _ => fail("an alias must not be treated as canonical")
  }
}

///|
test "canonical decode preserves overflow and blocklist exhaustion causes" {
  let codec = @moon-sqids.Sqids::new()
  try codec.decode_canonical("pup591lWlB") catch {
    @moon-sqids.CanonicalDecodeFailure(@moon-sqids.NumberOverflow) => ()
    error => raise error
  } noraise {
    _ => fail("expected a numeric overflow")
  }
  let blocked = @moon-sqids.Sqids::new(alphabet="abc", min_length=3, blocklist=[
    "cab", "abc", "bca",
  ])
  try blocked.decode_canonical("cab") catch {
    @moon-sqids.CanonicalEncodeFailure(@moon-sqids.BlocklistExhausted) => ()
    error => raise error
  } noraise {
    _ => fail("expected blocklist exhaustion")
  }
}
