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

The app currently ships English interface copy with fallback. The localization check verifies catalog completeness, not worldwide translated coverage.

## Regression evidence

The baseline run at commit `dcaf777` failed the three new regression cases as intended: cancellation, already-active verified access, and verified access arriving during failed sync. The six existing purchase lifecycle cases and the no-entitlement failure guard passed. [Baseline GitHub run](https://github.com/lanray07/LeaveWell/actions/runs/41318110016).

The corrected implementation also tests a successful sync discovering a purchase, no active subscription, and duplicate Restore taps. Tests seed real StoreKitTest transactions; only account-sync timing/failures are injected. The default production sync operation remains Apple's `AppStore.sync()`.

The first corrected release attempt passed core/native service checks, but its StoreKit job stopped producing progress during the first lifecycle case. That run was cancelled before archive/upload; it is not a passing test result. The next run pins the simulator destination architecture explicitly to arm64 to avoid duplicate universal simulator builds, and uses Xcode 27.1 for the production SDK to match the Duo captures. Existing-account physical-device confirmation is still pending because no iPad is detected by USB.
