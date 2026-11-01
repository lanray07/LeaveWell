# Restore Purchases investigation

## Delivery status

[GitHub release run 83](https://github.com/lanray07/LeaveWell/actions/runs/41328046507) succeeded for source `ffeb5d99cf31962a79ae6f82c0780bdf8bf6127f`: 13 core tests, 16 native service tests, 13 StoreKit lifecycle/restore tests and five Python localization checks passed. Xcode 27.1 archived and cloud-signed version 1.0 (83); Apple validation and upload succeeded on 1 November 2026 at 17:05 UTC. Temporary signing material was removed by the workflow.

The 170-image, 17-language Duo outer-display screenshot pack also passed its native locale/source checks, image/export audit and ZIP CRC validation. The captured and shipped app source tree is `aa01e6dc77eea0e798f9b65e40e2352a14a8a054`. The delivery checksum and locale list are in `marketing/duo/delivery.json`.

Apple processed build 83 and App Store Connect lists it as Ready to Submit. It is assigned to the existing Owner Device Testing internal group (one existing tester). Build-specific test instructions were saved; no tester was created.

Existing-account physical-device restore remains unverified: no iPad was detected by USB during this session. No new tester or Apple Account was created, and no App Review submission was made. Non-English app translation remains selected-flow coverage (117/597 strings), not full-app localization.

The owner requested testing with the existing TestFlight Apple Account. No new sandbox tester or account switch is part of this change.

## Reproduction

On build 57, Restore Purchases failed after the owner completed Apple's password prompt. A local StoreKit daemon trace recorded `accountMissing` during the app's transaction sync. A successful purchase and verified Plus access had already been observed on that device. This does not establish the cause of Apple's account failure.

The old restore implementation only refreshed `Transaction.currentEntitlements` after a successful `AppStore.sync()`. It skipped that check when sync threw, and treated StoreKit cancellation as a failure.

## Correction

- Read current, verified, unexpired Plus entitlements before requesting account sync. If Plus is already active, report that fact without asking for authentication again.
- When no active entitlement is available, keep the explicit, user-initiated `AppStore.sync()` recovery path.
- Recheck verified entitlements if sync fails. Disclose the sync failure even if StoreKit makes valid access available during authentication.
- Treat user cancellation quietly. Never unlock access from an error, an unverified transaction, an expired transaction, or a locally saved subscription flag.
- Keep duplicate-tap protection and real StoreKit lifecycle regression coverage.

## Limits

This app change cannot repair an Apple account session or establish that an unsuccessful server sync succeeded. Existing-account device testing is required after the new build is installed. No App Review submission is included.

The app includes 17 language bundles. Sixteen translated selected-flow sets cover 117 of 597 strings each (19.6%); other strings fall back to English. Native compilation and selected screenshot flows are checked, not full-app worldwide translation.

## Regression evidence

The baseline run at commit `dcaf777` failed the three new regression cases as intended: cancellation, already-active verified access, and verified access arriving during failed sync. The six existing purchase lifecycle cases and the no-entitlement failure guard passed. [Baseline GitHub run](https://github.com/lanray07/LeaveWell/actions/runs/41318110016).

The corrected implementation also tests a successful sync discovering a purchase, no active subscription, and duplicate Restore taps. Tests seed real StoreKitTest transactions; only account-sync timing/failures are injected. The default production sync operation remains Apple's `AppStore.sync()`.

The first corrected release attempt passed core/native service checks, but its StoreKit job stopped producing progress during the first lifecycle case. That run was cancelled before archive/upload; it is not a passing test result. The next run pins the simulator destination architecture explicitly to arm64 to avoid duplicate universal simulator builds, and uses Xcode 27.1 for the production SDK to match the Duo captures. Existing-account physical-device confirmation is still pending because no iPad is detected by USB.

A completed parallel check of the same correction passed the cancellation and already-active entitlement regressions, but exposed delayed StoreKit entitlement delivery after the sync callback. Restore now polls verified current entitlements for at most five seconds after sync success/failure. A failed sync remains an error even if Plus becomes available, and no entitlement means no access. The duplicate-tap test now sleeps briefly while awaiting its controlled sync callback instead of busy-yielding the main actor.


## Completed and subsequent validation

[Run 41321813824](https://github.com/lanray07/LeaveWell/actions/runs/41321813824) passed all 13 StoreKit lifecycle/regression tests for the corrected PurchaseService. Production SDK validation at `fdc3d24` passed 13 core tests, 16 native service tests (including compiled localized bundle checks) and five Python localization tests.

The subsequent full release run 41322822629 did not upload a build: its failed-sync regression could not establish the initial locked entitlement state after an earlier purchase test. Its baseline wait failed, then the test continued and skipped the sync callback because access was already active. This is a test-isolation failure; it does not prove the device account issue resolved. The test helper now explicitly syncs the cleared StoreKitTest environment before every case, aborts on a baseline timeout, and asserts that the failed-sync callback ran. Release run 41324452015 verifies that change before signing/upload.

No new sandbox tester was created, no Apple Account was switched, and no entitlement verification was bypassed. The physical iPad was not detected over USB during the 1 November check. Existing-account device restore remains unverified until reconnection and installation of the corrected TestFlight build.


Run 41324452015 established an empty baseline and passed 12 of 13 cases, including the failed-sync/verified-access regression. The preflight case expected zero sync calls immediately after seeding a test-server purchase, before its client entitlement was visible. It now waits for the actual verified client entitlement before exercising preflight restore. This preserves the regression's contract and assertion; no production behavior was changed for that fixture adjustment. Release run 41326189761 (build number 82) validates the updated fixtures and signed upload. Simulator test compilation is restricted to arm64; no test cases are skipped.


Run 41326189761 passed all seven restore regressions and five other lifecycle cases. The annual test's initial immediate entitlement assertion failed after a seeded purchase; the test still proceeded through its renewal/refund operations. The annual fixture now awaits verified active access before its assertions, just as the restore fixture does. Assertions for active access, forced renewal and removal after refund remain enabled. Run 41328046507 validates this test-only adjustment before archive/upload. The production PurchaseService and captured app source tree remain unchanged.


The obsolete build-82 workflow was cancelled by the build-83 dispatch after all 13 test results had been printed; its annual fixture assertion failed, so it did not archive or upload. Build 83 uses source `ffeb5d99cf31962a79ae6f82c0780bdf8bf6127f`. The app source tree still matches the complete 17-locale capture source; only test fixtures changed.


## Existing-account acceptance still required

Install TestFlight 1.0 (83) over the existing app without deleting its records. Open Settings > Explore LeaveWell Plus > Restore purchases. Already-active verified access should need no new account sign-in; otherwise complete any Apple authentication directly on the device and verify real entitlement restoration. Check cancellation/error behavior, record persistence, PDF export and app-lock return. A failed Apple account sync must not be reported as a successful restore. The TestFlight notes give the existing tester these steps and disclose the selected-flow translation limit.
