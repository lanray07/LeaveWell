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

The private key can be PEM text or base64 PEM. It is written with owner-only permissions to the ephemeral runner's temporary directory, and removed after the job. It is never included in build artifacts or printed. The workflow uses the App Store Connect API to locate exactly one existing app named LeaveWell and obtains its bundle ID; it does not create another app record. Apple cloud signing also requires the API key's role to have access to cloud-managed distribution certificates.

Artifacts are retained for seven days:

- `LeaveWell-simulator-and-tests`: simulator application and `.xcresult` test results.
- `LeaveWell-signed-IPA`: distribution IPA and debug symbols, after successful signing/export.

The export destination is `export`, so this workflow does not upload to TestFlight or submit an App Store version. An App Store distribution IPA is intended for distribution through Apple and is not an ad-hoc device-install package. TestFlight upload can be added as an explicitly requested next step.

The build number is the GitHub run number. Before adding upload, reconcile this sequence with any existing App Store Connect builds to ensure the next upload has a valid version/build number.

## Verified run

On 3 October 2026, [run 37141152860](https://github.com/lanray07/LeaveWell/actions/runs/37141152860) passed validation and signed export with Xcode 26.6 (17F113). It ran seven core tests, five iOS tests and five translation-gate tests. Both `build` and `archive` jobs completed successfully. The simulator and signed IPA artifacts are available on that run's summary while retained.

This verifies compilation, the supplied automated tests and distribution signing. It does not replace physical-device camera/microphone/biometric tests or a complete production-readiness review.
