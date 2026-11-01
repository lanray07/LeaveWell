# iPhone Duo screenshots

The initial English outer-display layout draft contains ten real Xcode 27.1 / iOS 27.1 iPhone Duo captures at 1398 × 2034 pixels, exported as opaque PNGs. It must be replaced by the latest verified regional-locale capture before upload. The original app images are preserved with proportional scaling. All records and document content are fictional.

`captures/manifest.json` records native source hashes and the GitHub capture run. `exports/manifest.json` records output hashes and dimensions. `english-preview.jpg` is the contact sheet for visual review.

Rebuild the English exports on Windows:

```powershell
./scripts/export_duo_screenshots.ps1 -RawPath "$PWD/marketing/duo/captures"
```

The exporter requires matching native locale provenance. It does not reuse English UI images for another language. Fonts are selected for Latin, Arabic, Indic, Japanese, Korean and Chinese scripts through Windows text shaping.

## Localization status

- Ten headlines, fictional-data disclosures and the Plus PDF disclosure are drafted for the 17 priority languages in `copy.json`.
- Sixteen translated selected-flow sets cover 117 of 597 catalog strings each. This is selected-screen coverage, not full-app localization. Other strings use English fallback. `translations/coverage.json` records coverage and review scope.
- The 17-locale native capture/layout validation is in progress. Caption drafts alone are not localized screenshot deliverables.
- There is no claim that the app interface is translated into all existing store-listing locales.

## Inner display

The simulator exposed 2007 × 2853 framebuffers, but the resulting inner images were black. They were rejected and are not included in the export pack. Do not resize the outer captures to substitute for the inner display. A real activated inner-display capture is required before adding that set.

Apple accepts the listed Duo outer and inner dimensions: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Release match

The native Duo presentation depends on the iOS 27.1 SDK. The release workflow now selects Xcode 27.1 explicitly for production build/archive; the StoreKit lifecycle suite remains on its separately supported Xcode 16.4 / iOS 18.5 test environment. A successful signed release with the matching catalog must precede publishing non-English assets. No screenshots have been uploaded to App Store Connect by this workflow.

The project generator previously declared the catalog as ordinary JSON, so Xcode copied it without compiling language bundles. It now uses `text.json.xcstrings`, derives project regions from the catalog, and includes a native resource regression test. The earlier French capture was rejected when its bundle language was English, even though its Foundation locale was French.
