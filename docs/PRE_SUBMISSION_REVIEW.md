# Pre-submission review - 3 October 2026

The review covers the shipping local edition: application code, persistence and original integrity, optional permissions, privacy lock, PDF exports, StoreKit subscriptions, project/signing configuration, marketing assets and App Store Connect metadata. Future connected services and untranslated languages are documented in RELEASE.md and are not advertised as available.

## Issues corrected

- App lock now cancels authentication on backgrounding, rejects stale successful callbacks and prevents simultaneous unlock requests. Inactive scenes remain shielded while biometric authentication temporarily interrupts the foreground.
- A separate privacy window covers presented camera, Quick Look and share controllers as well as the normal app. Enabling lock requires an available device passcode/owner-authentication policy. Locked underlying windows are hidden from accessibility, and their previous accessibility state is restored on unlock.
- Failed or unavailable voice transcription preserves existing typed meter/key notes and assistant questions; successful dictation appends to notes.
- Pending microphone permission cannot start recording after cancellation. Voice controls reject overlapping starts; meter, key and assistant recordings stop when the app backgrounds.
- File imports and document scanning keep the evidence form busy for the entire operation, preventing save or dismissal partway through importing originals.
- Report generation locks sharing controls for the export operation and prevents duplicate requests. Contact/deposit inclusion cannot change while an older PDF is being produced.
- Imported image formats are detected through Apple Uniform Type Identifiers instead of a restricted extension list; GIF/BMP and other supported images are rendered rather than silently indexed without their photograph.
- Included images and PDFs must decode successfully before report generation. Unreadable, empty or locked printable attachments produce an explicit error instead of an apparently complete report with missing content.
- Editing property details preserves existing reminders and reschedules pending reminders against the saved move-out date.
- Data export captures an explicit immutable archive snapshot for its manifest and original-file list.
- Promotional text identifies optional LeaveWell Plus. The description explains monthly/annual billing and directs users to their local storefront price; UK-specific price text is removed from the worldwide listing.

## Verification

New XCTest cases exercise background authentication cancellation, repeated unlock attempts, the privacy window lifecycle, microphone permission cancellation, persistence/export/original bytes, evidence-reference cleanup, corrupt-manifest preservation, PDF sharing controls, unreadable attachments and an actual GIF image embedded in PDF resources. Existing tests cover hashes/tampering/missing files, long-note pagination, search/planning/archive dates and the real StoreKit purchase lifecycle.

All 30 app source files, five XCTest source files, core models, workflow/project scripts and current listing/support/privacy copy were read. Public support, product and privacy URLs respond without signing in. No analytics, advertising or remote tenancy-data service is present. Permissions are requested for their corresponding feature; on-device-only speech is required with a typed/audio fallback.

Both ten-image App Store galleries were visually inspected. Every one of the 22 upload assets matches the manifest hash, RGB mode and declared size. The PDF renderer's existing 15-page long-note sample was rendered and inspected for margins, contents references, pagination and final text. The refreshed sample from run 37154369603 was rendered and all 15 pages were visually inspected; the contents references, margins and final long-note text remain correct.

App Store Connect privacy remains published as Data Not Collected; version metadata, categories, age rating, contact presence and subscription group/products are inspected without changing existing legal/account declarations. Existing default distribution to compatible Apple silicon Macs and Apple Vision Pro is preserved; compatibility has not been claimed as verified. Current release/test/build evidence is recorded in marketing/release-status.json. The purchase-review PNG produced by the reviewed source is byte-for-byte identical to the screenshot already attached to both subscription products.

The added PDF-resource regression test initially needed an explicit unwrap for the nullable Core Graphics page dictionary; this test compile error was corrected before the final validation run.

Automated verification on source cfc6381: seven core tests, fourteen iOS service tests, five localization tests and six real StoreKit lifecycle tests passed with zero failures. The production SDK simulator took longer to boot because of data migration; service tests themselves completed in about ten seconds. The full [release workflow](https://github.com/lanray07/LeaveWell/actions/runs/37154369603) succeeded: build 40 was signed, Apple validation/upload completed without errors, and Apple processing finished. The [guarded draft preparation](https://github.com/lanray07/LeaveWell/actions/runs/37156674257) selected build 40, read back the selection and restored the app to its existing draft with four READY_FOR_REVIEW items. The App Store Connect App Review page also visibly confirms the same draft has four items and is Ready for Review; the screenshot is saved at marketing/proof/pre-submission-ready.png. No final submission was performed. The production app source remains cfc63818c26cacf5bbc85bf2e6491ce1351bdcc3; the later helper/workflow and documentation commits do not change the app binary. Full release evidence is recorded in release-status.json.

## Remaining device checks

Meter/key dictation saves reviewed text; use Add evidence with an audio record when the original recording must be retained. Dedicated voice/audio attachments to meter/key fields remain a documented feature gap.

A physical iPhone/iPad is not available in this Windows session. Before final submission, run the device checklist in RELEASE.md: live camera/video/scanning, Apple sandbox purchases/restore/manage, biometric/passcode and modal lock transitions, notifications/date changes, iCloud-only imports, Files/AirDrop sharing, large/rotated attachments, VoiceOver and maximum Dynamic Type. Simulator tests and image inspection do not establish these physical-device results.

The 3 October review ended with an unsubmitted draft. On 4 October 2026, the follow-up submission was completed: Apple confirmed 4 Items Submitted, and the app 1.0 (40), LeaveWell Plus group, Monthly and Annual products each show Waiting for Review. Submission ID: 6f230d74-12ae-41bf-87c0-87f0434e9c96. The existing automatic-release-after-approval setting remains in place. Physical-device and Apple sandbox-device QA remain unperformed; submission does not establish those results. Public release has not occurred.

## Apple references checked

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): complete app functionality, accurate metadata and transparent subscriptions.
- [Product-page guidance](https://developer.apple.com/app-store/product-page/): storefront prices may differ by region; the purchase screen is the price authority.
- [LAContext invalidation](https://developer.apple.com/documentation/localauthentication/lacontext/invalidate%28%29): cancel a pending authentication policy evaluation when the app backgrounds.
- [Build selection API](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstoreversions-_id_-relationships-build): changes only the selected binary; the draft helper never sets submitted or accepts agreements.
- [Streamlined purchasing](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-streamlined-purchasing): currently turned on in App Store Connect; purchases made outside the app are received as transactions and verified by the app's entitlement listener/refresh.
