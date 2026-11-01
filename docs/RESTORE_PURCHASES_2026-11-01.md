# Restore Purchases investigation

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
