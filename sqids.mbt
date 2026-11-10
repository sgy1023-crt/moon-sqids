///|
/// The standard case-sensitive, URL-friendly Sqids alphabet.
pub let default_alphabet : String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

///|
/// The inclusive upper bound for compatibility with JavaScript Sqids.
pub let max_number : Int64 = 9007199254740991L

///|
/// An invalid alphabet or minimum length.
pub suberror ConfigError {
  NonAsciiAlphabet
  AlphabetTooShort(Int)
  DuplicateAlphabetCharacter(Char)
  InvalidMinLength(Int)
} derive(Debug)

///|
/// A number outside the supported range.
pub suberror EncodeError {
  NumberOutOfRange(Int64)
} derive(Debug)

///|
/// A decoded number exceeds max_number.
pub suberror DecodeError {
  NumberOverflow
} derive(Debug)

///|
/// An immutable Sqids configuration.
struct Sqids {
  alphabet : Array[Char]
  min_length : Int
}

///|
/// Create a codec. The alphabet must contain at least three distinct ASCII
/// characters. The minimum length is between 0 and 255, inclusive.
pub fn Sqids::new(
  alphabet? : String = default_alphabet,
  min_length? : Int = 0,
) -> Sqids raise ConfigError {
  let chars = alphabet.to_array()
  if chars.any(c => c.to_int() > 127) {
    raise NonAsciiAlphabet
  }
  if chars.length() < 3 {
    raise AlphabetTooShort(chars.length())
  }
  let seen = FixedArray::make(128, false)
  for c in chars {
    let index = c.to_int()
    if seen[index] {
      raise DuplicateAlphabetCharacter(c)
    }
    seen[index] = true
  }
  if min_length < 0 || min_length > 255 {
    raise InvalidMinLength(min_length)
  }
  shuffle(chars)
  { alphabet: chars, min_length, }
}

///|
/// Encode zero or more non-negative integers into a Sqids ID.
pub fn Sqids::encode(
  self : Sqids,
  numbers : ArrayView[Int64],
) -> String raise EncodeError {
  if numbers.is_empty() {
    return ""
  }
  let size = self.alphabet.length()
  let radix = size.to_int64()
  let mut offset = numbers.length() % size
  for index, number in numbers {
    if number < 0L || number > max_number {
      raise NumberOutOfRange(number)
    }
    let letter = self.alphabet[(number % radix).to_int()]
    // Reduce each term so long sequences cannot overflow the offset sum.
    offset = (offset + index % size + letter.to_int()) % size
  }
  self.encode_at(numbers, offset)
}

///|
fn Sqids::encode_at(
  self : Sqids,
  numbers : ArrayView[Int64],
  offset : Int,
) -> String {
  let alphabet = self.rotated_reversed(offset)
  let builder = StringBuilder()
  builder.write_char(self.alphabet[offset])
  let mut length = 1
  let digits : Array[Char] = []
  let radix = (alphabet.length() - 1).to_int64()
  for index, number in numbers {
    digits.clear()
    for remaining = number {
      digits.push(alphabet[1 + (remaining % radix).to_int()])
      let quotient = remaining / radix
      if quotient == 0L {
        break
      }
      continue quotient
    }
    for digit in digits.rev_iter() {
      builder.write_char(digit)
    }
    length += digits.length()
    if index + 1 < numbers.length() {
      builder.write_char(alphabet[0])
      length += 1
      shuffle(alphabet)
    }
  }
  if length < self.min_length {
    builder.write_char(alphabet[0])
    length += 1
    while length < self.min_length {
      shuffle(alphabet)
      let count = (self.min_length - length).min(alphabet.length())
      for index in 0..<count {
        builder.write_char(alphabet[index])
      }
      length += count
    }
  }
  builder.to_string()
}

///|
/// Decode an ID using this alphabet. Empty IDs and IDs containing characters
/// outside the alphabet return an empty array. Non-canonical IDs are accepted.
pub fn Sqids::decode(
  self : Sqids,
  id : String,
) -> Array[Int64] raise DecodeError {
  if id.is_empty() {
    return []
  }
  // Validate the whole ID before reading chunks, including ignored padding.
  let units = id.code_units()
  let mut offset = -1
  for index, unit in units {
    let c = unit.to_int()
    if c > 127 {
      return []
    }
    match self.alphabet.search(c.unsafe_to_char()) {
      Some(position) => if index == 0 { offset = position }
      None => return []
    }
  }
  let alphabet = self.rotated_reversed(offset)
  let radix = (alphabet.length() - 1).to_int64()
  let numbers : Array[Int64] = []
  let mut number = 0L
  let mut has_digits = false
  for index in 1..<units.length() {
    let c = units[index].to_int().unsafe_to_char()
    if c == alphabet[0] {
      if !has_digits {
        return numbers
      }
      numbers.push(number)
      number = 0L
      has_digits = false
      shuffle(alphabet)
      continue
    }
    let mut position = 1
    while alphabet[position] != c {
      position += 1
    }
    let digit = (position - 1).to_int64()
    if number > (max_number - digit) / radix {
      raise NumberOverflow
    }
    number = number * radix + digit
    has_digits = true
  }
  if has_digits {
    numbers.push(number)
  }
  numbers
}

///|
fn Sqids::rotated_reversed(self : Sqids, offset : Int) -> Array[Char] {
  let size = self.alphabet.length()
  Array::makei(size, index => self.alphabet[(offset + size - 1 - index) % size])
}

///|
fn shuffle(alphabet : Array[Char]) -> Unit {
  let size = alphabet.length()
  for left = 0, right = size - 1; right > 0; left = left + 1, right = right - 1 {
    let target = (
        left * right + alphabet[left].to_int() + alphabet[right].to_int()
      ) %
      size
    alphabet.swap(left, target)
  }
}
