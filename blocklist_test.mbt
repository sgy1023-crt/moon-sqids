///|
test "official blocklist replacement vector" {
  let sqids = @moon-sqids.Sqids::new(blocklist=["86Rf07"])
  assert_eq(sqids.encode([1L, 2L, 3L]), "se8ojk")
  assert_eq(sqids.decode("86Rf07"), [1L, 2L, 3L])
  assert_eq(sqids.decode("se8ojk"), [1L, 2L, 3L])
}

///|
test "official default blocklist and explicit replacement" {
  let default = @moon-sqids.Sqids::new()
  let disabled = @moon-sqids.Sqids::new(blocklist=[])
  let custom = @moon-sqids.Sqids::new(blocklist=["ArUO"])
  assert_eq(default.encode([4572721L]), "JExTR")
  assert_eq(default.decode("aho1e"), [4572721L])
  assert_eq(disabled.encode([4572721L]), "aho1e")
  assert_eq(custom.encode([4572721L]), "aho1e")
  assert_eq(custom.encode([100000L]), "QyG4")
  assert_eq(default.encode([4572721L]), "JExTR")
}

///|
test "official retry chain covers substring, digit prefix and digit suffix" {
  let sqids = @moon-sqids.Sqids::new(blocklist=[
    "JSwXFaosAN", "OCjV9JK64o", "rBHf", "79SM", "7tE6",
  ])
  assert_eq(sqids.encode([1000000L, 2000000L]), "1aYeB7bRUt")
  assert_eq(sqids.decode("1aYeB7bRUt"), [1000000L, 2000000L])
}

///|
test "short words match exactly and digit words ignore interior matches" {
  let sqids = @moon-sqids.Sqids::new(blocklist=["6Rf", "6Rf0"])
  assert_eq(sqids.encode([1L, 2L, 3L]), "86Rf07")
  let short = @moon-sqids.Sqids::new(blocklist=["pNd"])
  let unfiltered = @moon-sqids.Sqids::new(blocklist=[])
  assert_eq(unfiltered.encode([1000L]), "pnd")
  assert_true(short.encode([1000L]) != "pnd")
  assert_eq(short.decode("pnd"), [1000L])
}

///|
test "blocklist filtering honors lowercase and alphabet membership" {
  let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  let normalized = @moon-sqids.Sqids::new(alphabet=upper, blocklist=["sxnzKl"])
  let ignored = @moon-sqids.Sqids::new(alphabet=upper, blocklist=[
    "sx", "sxnzkl1", "sxnzkl好",
  ])
  assert_eq(normalized.encode([1L, 2L, 3L]), "IBSHOZ")
  assert_eq(ignored.encode([1L, 2L, 3L]), "SXNZKL")
}

///|
test "blocklist exhaustion is a typed encoding error" {
  let sqids = @moon-sqids.Sqids::new(alphabet="abc", min_length=3, blocklist=[
    "cab", "abc", "bca",
  ])
  try sqids.encode([0L]) catch {
    error => assert_true(error is @moon-sqids.BlocklistExhausted)
  } noraise {
    _ => fail("expected blocklist exhaustion")
  }
  assert_eq(sqids.encode([]), "")
}
