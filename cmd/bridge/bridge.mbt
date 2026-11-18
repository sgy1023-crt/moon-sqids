///|
fn failure(code : String, detail : String) -> Json {
  { "error": code.to_json(), "detail": detail.to_json() }
}

///|
/// Initialize one immutable registry and return its host-callable entry point.
#export_name("openRegistry")
pub fn open_registry(config : String) -> (String, String) -> String {
  let registry = @migration.Registry::parse(config) catch {
    error => {
      let reply = failure("invalid_manifest", @debug.to_string(error)).stringify()
      return (_, _) => reply
    }
  }
  (command, input) => run(registry, command, input).stringify()
}

///|
fn run(
  registry : @migration.Registry,
  command : String,
  input : String,
) -> Json {
  match command {
    "ready" => { "ok": true }
    "plan" =>
      registry.plan(input).to_json() catch {
        error => failure(error.code(), @debug.to_string(error))
      }
    "decode" =>
      try registry.decode(input) catch {
        error => failure(error.code(), @debug.to_string(error))
      } noraise {
        decoded =>
          {
            "version": decoded.version.to_json(),
            "numbers": decoded.numbers.to_json(),
            "legacy": decoded.legacy.to_json(),
          }
      }
    "encode" => {
      let numbers : Array[Int64] = @json.from_json(@json.parse(input)) catch {
        error => return failure("invalid_numbers", @debug.to_string(error))
      }
      { "id": registry.encode(numbers[:]).to_json() } catch {
        error => failure(error.code(), @debug.to_string(error))
      }
    }
    _ => failure("unknown_command", command)
  }
}

///|
/// Check a candidate configuration before a reader or issuer is switched.
#export_name("checkUpgrade")
pub fn check_upgrade(previous : String, next : String) -> String {
  let active = @migration.Registry::parse(previous) catch {
    error =>
      return failure("invalid_previous_manifest", @debug.to_string(error)).stringify()
  }
  let candidate = @migration.Registry::parse(next) catch {
    error =>
      return failure("invalid_candidate_manifest", @debug.to_string(error)).stringify()
  }
  active.check_upgrade(candidate) catch {
    error =>
      return failure("incompatible_upgrade", @debug.to_string(error)).stringify()
  }
  ({ "ok": true } : Json).stringify()
}
