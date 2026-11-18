///|
/// A change that would break the contract for links already issued.
pub suberror UpgradeError {
  RemovedVersion(String)
  ChangedVersion(String)
  ChangedLegacyVersion
  ChangedFields
} derive(Debug)

///|
/// Check the candidate against the manifest in use. Keep all deployed
/// profiles, the bare-ID mapping and the business fields fixed.
/// The issuer can switch current versions or roll back independently.
pub fn Registry::check_upgrade(
  self : Registry,
  candidate : Registry,
) -> Unit raise UpgradeError {
  if self.manifest.legacy != candidate.manifest.legacy {
    raise ChangedLegacyVersion
  }
  if self.manifest.fields != candidate.manifest.fields {
    raise ChangedFields
  }
  let next_profiles : Map[String, Profile] = Map([])
  for profile in candidate.manifest.profiles {
    next_profiles[profile.version] = profile
  }
  for profile in self.manifest.profiles {
    guard next_profiles.get(profile.version) is Some(next) else {
      raise RemovedVersion(profile.version)
    }
    if profile != next {
      raise ChangedVersion(profile.version)
    }
  }
}
