///|
priv struct Request {
  alphabet : String?
  min_length : Int?
  blocklist : Array[String]?
  numbers : Array[Int64]?
  id : String?
} derive(FromJson)

///|
fn Request::run(self : Request) -> Json {
  let codec = @sqids.Sqids::new(
    alphabet?=self.alphabet,
    min_length?=self.min_length,
    blocklist?=self.blocklist.map(words => words[:]),
  ) catch {
    error => return { "error": "config", "detail": @debug.to_string(error) }
  }
  match (self.numbers, self.id) {
    (Some(numbers), None) =>
      { "value": codec.encode(numbers[:]).to_json() } catch {
        error => { "error": "encode", "detail": @debug.to_string(error) }
      }
    (None, Some(id)) =>
      { "value": codec.decode(id).to_json() } catch {
        error => { "error": "decode", "detail": @debug.to_string(error) }
      }
    _ =>
      { "error": "request", "detail": "Provide exactly one of numbers or id" }
  }
}

///|
fn main {
  guard @env.get_env_var("MOONSQIDS_INTEROP_BATCH") is Some(input) else {
    abort("Set MOONSQIDS_INTEROP_BATCH to a JSON array of Sqids requests")
  }
  let requests : Array[Request] = try! @json.from_json(@json.parse(input))
  println(requests.map(request => request.run()).to_json().stringify())
}
