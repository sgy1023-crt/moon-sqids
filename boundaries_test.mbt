///|
test "empty input and zero" {
  let sqids = @moon-sqids.Sqids::new(min_length=255)
  assert_eq(sqids.encode([]), "")
  assert_eq(sqids.decode(""), [])
  let id = sqids.encode([0L])
  assert_eq(id.code_units().length(), 255)
  assert_eq(sqids.decode(id), [0L])
}

///|
test "minimum length is a lower bound and padding works at 255" {
  let unpadded = @moon-sqids.Sqids::new(min_length=1)
  assert_eq(unpadded.encode([1L, 2L, 3L]), "86Rf07")
  let padded = @moon-sqids.Sqids::new(alphabet="abc", min_length=255)
  let numbers = [0L, 1L, @moon-sqids.max_number]
  let id = padded.encode(numbers)
  assert_eq(id.code_units().length(), 255)
  assert_eq(padded.decode(id), numbers)
}

///|
test "zero, increasing inputs and upper boundary match the JS oracle" {
  let sqids = @moon-sqids.Sqids::new()
  assert_eq(sqids.encode([0L]), "bM")
  assert_eq(sqids.encode([@moon-sqids.max_number]), "ABARpJzdz9")
  assert_eq(sqids.decode("ABARpJzdz9"), [@moon-sqids.max_number])
  let wide = [9007199254740990L, 0L, 9007199254740991L]
  assert_eq(sqids.encode(wide), "9D9UhqIZIzFgqjTHPfgEgL")
  assert_eq(sqids.decode("9D9UhqIZIzFgqjTHPfgEgL"), wide)
  let increasing = [
    0L, 1L, 61L, 62L, 4294967295L, 4294967296L, 9007199254740991L,
  ]
  assert_eq(sqids.decode(sqids.encode(increasing)), increasing)
}

///|
test "encoding rejects out-of-range values at any position" {
  let sqids = @moon-sqids.Sqids::new()
  for
    bad in [-9223372036854775808L, -1L, 9007199254740992L, 9223372036854775807L] {
    try sqids.encode([1L, bad, 0L]) catch {
      @moon-sqids.NumberOutOfRange(number) => assert_eq(number, bad)
      error => raise error
    } noraise {
      _ => fail("expected NumberOutOfRange")
    }
  }
}

///|
test "decoding rejects overflow before performing arithmetic" {
  let sqids = @moon-sqids.Sqids::new()
  try sqids.decode("pup591lWlB") catch {
    error => assert_true(error is @moon-sqids.NumberOverflow)
  } noraise {
    _ => fail("expected NumberOverflow")
  }
  // Spec validates the whole alphabet before attempting to decode.
  assert_eq(sqids.decode("pup591lWlB*"), [])
}

///|
test "decoding accepts aliases but rejects non-alphabet characters even in padding" {
  let sqids = @moon-sqids.Sqids::new()
  assert_eq(sqids.decode("bMM"), [0L])
  assert_eq(sqids.decode("b"), [])
  assert_eq(sqids.decode("86Rf07x"), [1L, 2L, 3L])
  assert_eq(sqids.decode("86Rf07xd4z*"), [])
  assert_eq(sqids.decode("86Rf07🐙"), [])
}

///|
test "configuration rejects empty, short, repeated and multibyte alphabets" {
  for alphabet in ["", "a", "ab"] {
    try @moon-sqids.Sqids::new(alphabet~) catch {
      @moon-sqids.AlphabetTooShort(length) =>
        assert_eq(length, alphabet.code_units().length())
      error => raise error
    } noraise {
      _ => fail("expected AlphabetTooShort")
    }
  }
  try @moon-sqids.Sqids::new(alphabet="aAca") catch {
    @moon-sqids.DuplicateAlphabetCharacter(c) => assert_eq(c, 'a')
    error => raise error
  } noraise {
    _ => fail("expected DuplicateAlphabetCharacter")
  }
  for alphabet in ["aéZ", "ab🐙"] {
    try @moon-sqids.Sqids::new(alphabet~) catch {
      error => assert_true(error is @moon-sqids.NonAsciiAlphabet)
    } noraise {
      _ => fail("expected NonAsciiAlphabet")
    }
  }
}

///|
test "configuration accepts distinct case, punctuation and ASCII control characters" {
  let sqids = @moon-sqids.Sqids::new(alphabet="aB!", blocklist=[])
  assert_eq(sqids.encode([1L, 2L, 3L]), "BBaB!aBB")
  assert_eq(sqids.decode("BBaB!aBB"), [1L, 2L, 3L])
  let mixed_case = @moon-sqids.Sqids::new(alphabet="aAb")
  assert_eq(mixed_case.decode(mixed_case.encode([42L])), [42L])
  let ascii = @moon-sqids.Sqids::new(alphabet="a \t\n\u0000B", blocklist=[])
  assert_eq(ascii.encode([1L, 2L, 3L]), "\u0000 BB\n ")
  assert_eq(ascii.decode("\u0000 BB\n "), [1L, 2L, 3L])
}

///|
test "configuration rejects out-of-range minimum length" {
  for invalid in [-1, 256] {
    try @moon-sqids.Sqids::new(min_length=invalid) catch {
      @moon-sqids.InvalidMinLength(length) => assert_eq(length, invalid)
      error => raise error
    } noraise {
      _ => fail("expected InvalidMinLength")
    }
  }
}

///|
test "seeded integer sequences round-trip in three configurations" {
  let codecs = [
    @moon-sqids.Sqids::new(),
    @moon-sqids.Sqids::new(min_length=64),
    @moon-sqids.Sqids::new(alphabet="aBcD!0123456789", min_length=30, blocklist=[]),
  ]
  let mut state = 0x5eed_cafeU
  for sample in 0..<200 {
    let numbers = Array::makei(sample % 9, _ => {
      state = state * 1664525U + 1013904223U
      let high = (state & 0x1f_ffffU).to_int64()
      state = state * 1664525U + 1013904223U
      (high << 32) + state.to_int64()
    })
    for codec in codecs {
      let id = codec.encode(numbers)
      assert_eq(codec.decode(id), numbers)
      assert_eq(codec.encode(numbers), id)
    }
  }
}
