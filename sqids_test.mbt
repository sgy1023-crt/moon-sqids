///|
test "official default vector" {
  let sqids = @moon-sqids.Sqids::new()
  assert_eq(sqids.encode([1L, 2L, 3L]), "86Rf07")
  assert_eq(sqids.decode("86Rf07"), [1L, 2L, 3L])
}

///|
test "official minimum length vector" {
  let sqids = @moon-sqids.Sqids::new(min_length=10)
  assert_eq(sqids.encode([1L, 2L, 3L]), "86Rf07xd4z")
  assert_eq(sqids.decode("86Rf07xd4z"), [1L, 2L, 3L])
}

///|
test "official custom alphabet vector" {
  let sqids = @moon-sqids.Sqids::new(
    alphabet="FxnXM1kBN6cuhsAvjW3Co7l2RePyY8DwaU04Tzt9fHQrqSVKdpimLGIJOgb5ZE",
  )
  assert_eq(sqids.encode([1L, 2L, 3L]), "B4aajs")
  assert_eq(sqids.decode("B4aajs"), [1L, 2L, 3L])
}
