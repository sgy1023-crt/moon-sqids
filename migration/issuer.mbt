///|
/// The deployed readers cannot resolve IDs that the candidate would issue.
pub suberror IssuerError {
  ReadersIncompatible(UpgradeError)
  ReadersMissingVersion(String)
} derive(Debug)

///|
/// Check the writer configuration after the candidate profiles have been
/// staged on readers. Compare against the manifest actually deployed there.
pub fn Registry::check_issuer(
  self : Registry,
  writer : Registry,
) -> Unit raise IssuerError {
  self.check_upgrade(writer) catch {
    error => raise ReadersIncompatible(error)
  }
  if !self.codecs.contains(writer.manifest.current) {
    raise ReadersMissingVersion(writer.manifest.current)
  }
}
