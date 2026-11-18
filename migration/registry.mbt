///|
/// Public-link policy shared by issuers, readers and offline migration.
pub(all) struct Manifest {
  current : String
  legacy : String?
  fields : Array[Field]
  profiles : Array[Profile]
} derive(FromJson)

///|
/// An inclusive range for one component of a public ID.
pub(all) struct Field {
  name : String
  min : Int64
  max : Int64
} derive(Eq, FromJson)

///|
/// An immutable definition for a published version. All Sqids options are explicit.
pub(all) struct Profile {
  version : String
  alphabet : String
  min_length : Int
  blocklist : Array[String]
} derive(Eq, FromJson)

///|
/// Configuration rejected before a registry can be used.
pub suberror ManifestError {
  BadJson(String)
  BadVersion(String)
  DuplicateVersion(String)
  UnconfiguredVersion(String)
  UnsafeAlphabet(String)
  InvalidSqids(String, @sqids.ConfigError)
  InvalidField(String)
  DuplicateField(String)
  EmptySchema
} derive(Debug)

///|
/// An immutable registry for a single public ID domain.
struct Registry {
  manifest : Manifest
  codecs : Map[String, @sqids.Sqids]
}

///|
/// Parse and validate the same JSON manifest used by the migration CLI.
/// Int64 range bounds are decimal strings in JSON.
pub fn Registry::parse(text : String) -> Registry raise ManifestError {
  let manifest : Manifest = @json.from_json(@json.parse(text)) catch {
    error => raise BadJson(@debug.to_string(error))
  }
  Registry::new(manifest)
}

///|
/// Validate every profile and the business schema before encoding or decoding.
pub fn Registry::new(manifest : Manifest) -> Registry raise ManifestError {
  if manifest.fields.is_empty() {
    raise EmptySchema
  }
  let names : Map[String, Unit] = Map([])
  for field in manifest.fields {
    if field.name.is_empty() ||
      field.min < 0L ||
      field.min > field.max ||
      field.max > @sqids.max_number {
      raise InvalidField(field.name)
    }
    if names.contains(field.name) {
      raise DuplicateField(field.name)
    }
    names[field.name] = ()
  }
  let codecs : Map[String, @sqids.Sqids] = Map([])
  for profile in manifest.profiles {
    let version = profile.version
    if !valid_version(version) {
      raise BadVersion(version)
    }
    if codecs.contains(version) {
      raise DuplicateVersion(version)
    }
    if !profile.alphabet
      .iter()
      .all(c => {
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '-' ||
        c == '_'
      }) {
      raise UnsafeAlphabet(version)
    }
    let codec = @sqids.Sqids::new(
      alphabet=profile.alphabet,
      min_length=profile.min_length,
      blocklist=profile.blocklist[:],
    ) catch {
      error => raise InvalidSqids(version, error)
    }
    codecs[version] = codec
  }
  if !codecs.contains(manifest.current) {
    raise UnconfiguredVersion(manifest.current)
  }
  if manifest.legacy is Some(version) && !codecs.contains(version) {
    raise UnconfiguredVersion(version)
  }
  let snapshot = Manifest::{
    ..manifest,
    fields: manifest.fields.copy(),
    profiles: manifest.profiles.map(profile => Profile::{
      ..profile,
      blocklist: profile.blocklist.copy(),
    }),
  }
  { manifest: snapshot, codecs, }
}

///|
fn valid_version(version : String) -> Bool {
  let length = version.code_units().length()
  length >= 1 &&
  length <= 32 &&
  version
  .iter()
  .all(c => (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')
}
