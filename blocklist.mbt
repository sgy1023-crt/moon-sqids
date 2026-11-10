///|
priv struct BlockedWord {
  text : String
  length : Int
  has_digit : Bool
}

///|
fn filter_blocklist(
  alphabet : String,
  words : ArrayView[String],
) -> Array[BlockedWord] {
  let lowercase_alphabet = alphabet.to_lower()
  let filtered = []
  for word in words {
    // U+212A is the only non-ASCII character that lowercases to ASCII in JS.
    let text = word.replace_all(old="K", new="k").to_lower()
    let length = text.code_units().length()
    if length < 3 || !text.iter().all(c => lowercase_alphabet.contains_char(c)) {
      continue
    }
    let has_digit = text.iter().any(c => c >= '0' && c <= '9')
    filtered.push({ text, length, has_digit, })
  }
  filtered
}

///|
fn is_blocked(id : String, blocklist : Array[BlockedWord]) -> Bool {
  if blocklist.is_empty() {
    return false
  }
  let text = id.to_lower()
  let length = text.code_units().length()
  for word in blocklist {
    if word.length > length {
      continue
    }
    let matches = if word.length == 3 {
      text == word.text
    } else if word.has_digit {
      text.has_prefix(word.text) || text.has_suffix(word.text)
    } else {
      text.contains(word.text)
    }
    if matches {
      return true
    }
  }
  false
}
