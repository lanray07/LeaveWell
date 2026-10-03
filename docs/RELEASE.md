# Release status and remaining work

## Implemented versus pending

| Area | Current behavior | Required before a complete premium release |
|---|---|---|
| Native app | SwiftUI iPhone/iPad project targeting iOS 18+, adaptive system controls; Xcode 26.6 simulator build and 12 Swift tests passed on GitHub | Broader simulator workflows, physical-device QA, designer review |
| Onboarding | Four steps with native symbol illustrations | Commission or generate the requested human renter illustration and report artwork |
| Property setup | Main property/date/deposit/contact fields; GB regions or other jurisdiction | Full international country/region dataset and region-specific reviewed guidance |
| Plan | Calendar-based checklist and optional reminders | Smarter notifications around actual handover, rescheduling on date changes |
| Guided capture | Fixture checks, multiple original imports, native camera | Custom AVFoundation grid, wide/detail presets, annotation derivatives |
| Video | Native high-quality capture with narration, review and import | Dedicated pause/resume, narration editing and long-video lifecycle tests |
| Voice | Local audio, optional on-device transcription, typed fallback | Broader natural-language navigation, structured voice field suggestions, voice/audio attachments to meters/keys |
| Meter OCR | On-device candidates; user selects and explicitly confirms | Real-world meter corpus evaluation and correction workflows |
| Keys | Item/handover creation, explicit review and photo association | Edit/delete individual readings and access items; optional acknowledgement/signature |
| Vault | PDF/images, native page scanning, Files/library imports | Dedicated share-sheet extension, encrypted backup restore/import and embedded PDF search/OCR |
| Comparison | User-selected originals and current photos, saved factual notes | Inventory room/item extraction and visual side-by-side viewer |
| Assistant | Case-grounded deterministic queries and TTS | Reviewed multilingual intent parsing and optional AI service with explicit privacy choice |
| Search | AND matching on room/name/notes/transcript/metadata | Document content extraction and semantic search |
| Report | Paginated PDF, embedded images/PDF pages, original integrity checks, sharing toggles | Generated-PDF device visual QA, arbitrary imported document validation, photo orientation/large corpus stress tests |
| Integrity | Write-once original descriptors, separate notes, hashes, distinct dates | Tamper-evident signed history, independent time attestation if ever offered, tested schema migration |
| Privacy | iOS complete file protection, app lock, local-only storage, explicit exports/deletion | Final operator privacy/support policies and App Store privacy label review |
| Cloud | Contracts only; UI truthfully says saved on device | Private authenticated backend, end-to-end encryption design, retries, conflict handling, per-file verified acknowledgements, remote deletion |
| Collaboration | Contracts only | Invitations, scoped case roles, verified identity attribution, revocation and conflict tests |
| Sharing links | Ordinary local PDF sharing only | Expiry/revocation/download-policy backend; never promise that existing downloads can be revoked |
| Purchases | StoreKit 2 Plus paywall, verified active subscriptions, restore/manage, monthly £2.99 and annual £19.99 UK products | Apple sandbox account/device verification and subscription review approval |
| Localization | English catalog plus gated translation workflow | Human-reviewed 16-language translation sets, localized permission prompts, plural variants, locale/date/RTL QA |
| Account management | No account or credentials required | Sign in with Apple, Keychain tokens, account deletion, server-side erasure if connected edition ships |

## Mac verification

1. Regenerate the project and validate resources.
2. Run core tests and iOS XCTest suite. Fix any SDK-specific type errors before running UI tests.
3. On a clean simulator: complete onboarding, add an empty case, add custom rooms, review fixtures, add notes, restart and verify persistence.
4. On a physical iPhone: deny and grant camera/microphone/speech permissions; capture originals; record voice and video; scan multi-page documents; import from Files and Photos (including iCloud-only items).
5. Move in and out of the background during capture, transcription, file imports and biometric lock. Confirm no evidence disappears, pending work is not duplicated, and private snapshots are masked when app lock is enabled.
6. Change dates across UK DST boundaries. Verify reminders in Notification Settings and cancellation after deleting cases.
7. OCR leading zeroes, decimal registers and serial numbers. Verify selection never bypasses confirmation.
8. Create a report with long notes, landscape/portrait HEIC images, rotated PDFs, many rooms and excluded items. Review every page, captions, contents references, margins and missing-file errors.
9. Enable the declaration/contact/deposit toggles; confirm the exported PDF matches the selection. Remove an original file in a test vault and verify the app reports failure rather than exporting a partial report.
10. Use maximum accessibility text sizes, VoiceOver, dark mode, increased contrast, Reduce Motion, Arabic RTL and pseudo-localization. Fix truncation and focus issues.
11. Share/export to Files and AirDrop, inspect all exported files, delete evidence and cases, restart and verify orphan-file reconciliation. Confirm no external copy is claimed to be deleted.
12. Configure signing, owned bundle IDs, StoreKit products, support URL, privacy URL, screenshots, final artwork and App Store metadata. Archive and validate with Xcode before any upload.

GitHub validation run: https://github.com/lanray07/LeaveWell/actions/runs/37141152860. The workflow resolves the existing LeaveWell app through a read-only App Store Connect lookup and uses Apple automatic provisioning/cloud signing for IPA export. A manual upload input validates and uploads the signed binary to App Store Connect. App Review submission and release are not automated.
