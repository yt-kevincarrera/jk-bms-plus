/// The author's Ed25519 public key, 32 bytes.
///
/// Written by `dart run tool/license_keygen.dart keygen`, which keeps the
/// private half in a file outside the repository. Keys the app accepts are
/// signed with that private half and with nothing else, so:
///
/// - **Lose the private key and no new licences can ever be issued** for
///   builds carrying this public key. Back it up next to the APK signing key,
///   see docs/RELEASING.md and docs/LICENSING.md.
/// - Replacing this constant invalidates every key already sold. Do not.
///
/// All zeros means no key pair has been generated yet, and that is also the
/// switch: while it is zeros, licensing is off in the whole app (see
/// `LicenseController.enabled`). Everything is unlocked, no trial clock runs,
/// no licence card is shown. Running `keygen` turns it on. Ship freely
/// before then; the day the sales channel is ready, one command and one
/// commit make it real.
const List<int> licensePublicKey = [
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
];

/// Whether a real key pair has been baked in.
bool get licensePublicKeyIsSet => licensePublicKey.any((b) => b != 0);
