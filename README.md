# LeaveWell

**Move out organised. Leave with the evidence.**

A native SwiftUI app for renter-owned move-out records. This repository contains an offline local edition, an Xcode project, a portable Swift domain package, iOS integrity tests and a reviewed-localization workflow.

## Open and run

1. On a Mac, open `LeaveWell.xcodeproj` in a current stable Xcode with an iOS 18 or newer SDK.
2. Select the **LeaveWell** scheme and an iPhone simulator. Build and run.
3. For a physical device, set your signing team and your owned bundle identifier in both targets. The included `com.leavewell.app` identifier is a development placeholder.
4. Use a physical iPhone to verify camera, document scanning, microphone, on-device speech, biometrics and file protection.

No third-party application dependencies, backend credentials or XcodeGen installation are required. The project is checked in. After adding source files, run `python3 scripts/generate_project.py` to refresh it.

## Implemented local experience

- Four-screen onboarding and calm adaptive SwiftUI layouts, system typography, native navigation, dark color variants and accessible controls.
- Multiple move-out records, property details, England-first region selection, custom rooms and editable move-out dates.
- Calendar-based move-out plan, explicit task review, room fixture review and optional local notifications.
- Native photo/video camera with review, retake, flash and zoom; multi-file library imports; labelled notes, factual condition states and room association.
- Local audio recording and optional **on-device-only** speech transcription, editable text and visible typed alternatives.
- Meter records retaining leading zeroes; Vision OCR drafts with explicit selection and human confirmation.
- Keys, quantities, recipient, handover method/date, review confirmation and linked photographs.
- Document vault, original inventory import, native document scanning, original-file preview, factual move-in/move-out comparison notes.
- Search across labels, notes, transcripts, rooms, original filenames and evidence IDs; chronological activity history.
- Case-grounded deterministic assistant for incomplete rooms, meters, access items and evidence search, with speech input and read-aloud output.
- Paginated A4 PDF with cover, contents, room index, images, imported PDF pages, captions, IDs, hashes, readings, handover records, document index and optional declaration. Videos/audio are indexed and exported separately.
- Private local persistence, iOS complete file protection, SHA-256 originals, explicit timestamps, integrity verification on previews and exports, optional device-owner app lock, deletion and data export.
- English String Catalog and 16-language translation publishing workflow with review gates; native layout direction and text expansion support.
- StoreKit 2 service for verified purchases, updates and restoration, ready for real product identifiers. Monetization is not enabled in the local edition.

## Verification on the authoring machine

This project was authored on Windows, which cannot compile SwiftUI/UIKit or run an iOS simulator. The portable core was compiled and tested with Swift 6.3.1; seven core tests passed. iOS source parsing and resource/project checks were also run. **An iOS build, simulator run and physical-device QA remain unverified.** The three iOS vault tests and two PDF tests are supplied for execution on a Mac.

Run portable tests:

```sh
swift test
python3 scripts/localization.py --check
python3 scripts/validate_project.py
python3 scripts/test_localization.py
```

Windows paths containing spaces can trigger a SwiftPM output-map error. Use an absolute scratch path without spaces:

```powershell
swift test --scratch-path C:/Users/User/.codex/tmp/leavewell-build
```

Run iOS tests:

```sh
xcodebuild -project LeaveWell.xcodeproj -scheme LeaveWell \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

Choose a simulator actually installed in your Xcode. CI selects an available iPhone automatically.

## Release boundary

This is an implemented local foundation, **not a production-ready or App Store-submitted release**. See [`docs/RELEASE.md`](docs/RELEASE.md) for the capability matrix and remaining work: actual device validation, connected services, collaboration, expiring links, commercial configuration, full translations and expanded camera/video tools.

The pasted brief ended after section 28. No requirements beyond the supplied text were inferred as complete.

## Architecture

`LeaveWell/Core` contains platform-independent Codable value models, archive versioning, room guidance, search and calendar planning. `CaseStore` owns observable state and commits complete record snapshots atomically before publishing changes to the UI. Protected original files live outside the record index and are imported by `EvidenceVault`, an actor that hashes in streaming chunks and checks paths and integrity.

SwiftData was not chosen for this initial version: a versioned Codable manifest makes exact original-file metadata, portable tests and explicit export straightforward. Before large-scale release, evaluate SQLite/SwiftData for record indexing and background persistence, and add tested schema migrations. The JSON index is currently written on the main actor and is not intended for unbounded case histories.

Online authentication, sync, private sharing and collaboration have protocol boundaries in `ServiceContracts.swift`; they have no fake implementations or user-visible success states. There is no network AI provider or external analytics SDK. Locale and jurisdiction are stored separately from evidence and core logic makes no jurisdictional legal decisions.

Original hashes identify file bytes, **not proof of capture time or legal authenticity**. Camera times are device-clock times recorded when the capture callback completes. Imported capture times remain unknown rather than being reconstructed from unverified EXIF. Scanned pages are captured derivatives of paper and are labelled as scans. Read [`docs/PRIVACY.md`](docs/PRIVACY.md) for storage and sharing details.
