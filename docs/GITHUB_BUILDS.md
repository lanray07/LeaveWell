# Build LeaveWell with Xcode on GitHub

The repository's **iOS validation** workflow uses a GitHub-hosted `macos-26` runner. It logs the installed Xcode version, checks resources/localization, runs the portable Swift tests, builds the iOS application and runs the iOS vault/PDF tests on an available iPhone simulator.

Pushes and pull requests run validation. To additionally export an App Store distribution IPA, open **Actions → iOS validation → Run workflow**, select `main`, and enable **Export a signed IPA using the Apple secrets**. From an authenticated GitHub CLI:

```sh
gh workflow run ios.yml --repo lanray07/LeaveWell --ref main -f archive=true
```

The signed build runs only after validation passes. It uses the existing repository secrets:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY`

The private key can be PEM text or base64 PEM. It is written with owner-only permissions to the ephemeral runner's temporary directory, and removed after the job. It is never included in build artifacts or printed. The workflow resolves the permanent App Store Connect app ID `6818834817` and verifies bundle ID `com.LeaveWell.app`, so listing-name changes do not break signing. It does not create another app record. Apple cloud signing also requires the API key's role to have access to cloud-managed distribution certificates.

Artifacts are retained for seven days:

- `LeaveWell-simulator-and-tests`: simulator application and `.xcresult` test results.
- `LeaveWell-signed-IPA`: distribution IPA and debug symbols, after successful signing/export.

The export destination is `export`. The optional **Validate and upload the signed build to App Store Connect** input validates and uploads that IPA using the existing Apple API secrets. Upload alone does not select a build for review, invite testers, submit a version or release the app. An App Store distribution IPA is intended for distribution through Apple and is not an ad-hoc device-install package.

The marketing version is 1.0, matching the existing App Store Connect version. The build number is the GitHub run number; Apple validation rejects conflicting version/build numbers before upload.

## Verified run

On 3 October 2026, [run 37141152860](https://github.com/lanray07/LeaveWell/actions/runs/37141152860) passed validation and signed export with Xcode 26.6 (17F113). It ran seven core tests, five iOS tests and five translation-gate tests. Both `build` and `archive` jobs completed successfully. The simulator and signed IPA artifacts are available on that run's summary while retained.

This verifies compilation, the supplied automated tests and distribution signing. It does not replace physical-device camera/microphone/biometric tests or a complete production-readiness review.

## App Store screenshots

Enable **Capture ten real app screens on iPhone and iPad**, or run:

```sh
gh workflow run ios.yml --repo lanray07/LeaveWell --ref main -f screenshots=true
```

After validation, `scripts/capture_marketing.py` installs the Debug app on available iPhone and 13-inch iPad simulators. It launches ten real feature views with clearly fictional demo records, waits for each view's readiness marker and saves the native screenshots to `LeaveWell-real-marketing-screens` (30-day retention). The photo fixture is copied into the simulator bundle only during this step. Release builds exclude the capture routes and sample-record code.

For artwork-only refreshes, **App Store screenshots** (`marketing.yml`) builds the Debug application and captures each device family on an isolated macOS runner. It preserves partial captures on failure and bounds OS boot waits. Download its two family artifacts into `marketing/captures/iphone` and `marketing/captures/ipad`.

Download the captures, then run `python scripts/export_marketing.py --raw marketing/captures` on the Windows artwork workspace to produce deterministic English typography and App Store image dimensions. Final exports and their provenance are under `marketing`.
