# Local edition privacy and evidence handling

## Storage

- No account, backend, tracking SDK or remote AI endpoint is present.
- The manifest and original media are stored in Application Support with `NSFileProtectionComplete`. This uses iOS device encryption and locks files while the device is locked; the local edition does not claim a separate app-managed encryption key.
- The vault is excluded from automatic device/iCloud backups. This prevents unintended backup disclosure but means **users must export their records**. The onboarding and settings state this limitation.
- Preview and export copies are protected temporary files. They are cleared on the next app launch and when deleting a case. Copies saved or shared outside LeaveWell are controlled by their recipient.
- On-device speech is required. If it is unsupported or permission is denied, no server fallback occurs; the local audio recording and typed input remain available.
- OCR is performed on device using Vision. Suggested digits are drafts and never automatically treated as confirmed.
- App lock uses device-owner authentication (biometrics or device passcode), hides content whenever the scene becomes inactive and requires another authentication to reveal records.
- The app intentionally does not ask for full Photo Library read access: PhotosPicker grants access to selected items.

## Originals

- Imports are copied without deliberate byte changes and SHA-256 hashed in chunks.
- Camera images use the camera's original file URL where available. If Apple's picker supplies only `UIImage`, a full-quality JPEG is encoded as the initial stored original. This is **not a RAW/EXIF-preserving forensic capture claim**.
- Video capture retains the supplied movie. Document scanning saves each scanned page as its initial full-quality JPEG; the physical paper original is not represented as an immutable digital source.
- Captured, imported, created and updated times remain separate. Unknown import capture times are shown as unknown.
- Hash checks are required before preview and export. Hashes protect against unnoticed byte changes relative to the stored manifest, not an attacker who controls and edits both manifest and files.
- User attribution is a locally entered display name, not independently verified identity.

## Sharing and deletion

The report includes the address and tenant/contributor names. Contact and deposit details are opt-in. Imported documents can contain private details that are not automatically redacted. Excluded evidence is omitted from the PDF; the timeline is generated from included records to avoid leaking excluded labels. Full data export intentionally includes all stored records and files.

Deleting evidence commits removal from the manifest before deleting its original files. If interrupted after the manifest commit, startup reconciliation removes orphaned files. A deletion error is surfaced. Deleting a case cancels its reminders. The app cannot erase copies already saved to Files or sent to another person.

Future connected features require separate privacy design, real authorization, encrypted transport, a server erasure contract and remote-deletion tests. The included protocol declarations are not a privacy guarantee for an unbuilt server.
