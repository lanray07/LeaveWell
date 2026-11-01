# iPhone Duo screenshots

The initial English outer-display layout draft contains ten real Xcode 27.1 / iOS 27.1 iPhone Duo captures at 1398 × 2034 pixels, exported as opaque PNGs. It must be replaced by the latest verified regional-locale capture before upload. The original app images are preserved with proportional scaling. All records and document content are fictional.

`captures/manifest.json` records native source hashes and the GitHub capture run. `exports/manifest.json` records output hashes and dimensions. `previews/<locale>.jpg` contains each ten-screen contact sheet. `UPLOAD_MAP.csv` maps folders to App Store localizations. No assets have been uploaded to App Store Connect by these scripts.

Collect completed native captures, rebuild all available exports on Windows, then audit/package the complete set:

```powershell
python scripts/collect_duo_captures.py --run 41323083971
$duoLocales = (Get-Content marketing/duo/copy.json -Raw | ConvertFrom-Json).locales.PSObject.Properties.Name
./scripts/export_duo_screenshots.ps1 -RawPath "$PWD/marketing/duo/captures" -Locales $duoLocales
python scripts/package_duo_screenshots.py
```

The exporter requires matching native locale provenance. It does not reuse English UI images for another language. Fonts are selected for Latin, Arabic, Indic, Japanese, Korean and Chinese scripts through Windows text shaping.

## Localization status

- Ten headlines, fictional-data disclosures and the Plus PDF disclosure are drafted for the 17 priority languages in `copy.json`.
- Sixteen translated selected-flow sets cover 117 of 597 catalog strings each. This is selected-screen coverage, not full-app localization. Other strings use English fallback. `translations/coverage.json` records coverage and review scope.
- All 17 native locale captures passed the bundle, regional locale, translated sample, nonblank image and dimension checks. Export contact-sheet review is recorded in `translations/coverage.json`. Caption drafts alone are not localized screenshot deliverables.
- There is no claim that the app interface is translated into all existing store-listing locales.

## Inner display

The simulator exposed 2007 × 2853 framebuffers, but the resulting inner images were black. They were rejected and are not included in the export pack. Do not resize the outer captures to substitute for the inner display. A real activated inner-display capture is required before adding that set.

Apple accepts the listed Duo outer and inner dimensions: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Release match

The native Duo presentation depends on the iOS 27.1 SDK. The release workflow now selects Xcode 27.1 explicitly for production build/archive; the StoreKit lifecycle suite remains on its separately supported Xcode 16.4 / iOS 18.5 test environment. A successful signed release with the matching catalog must precede publishing non-English assets. No screenshots have been uploaded to App Store Connect by this workflow.

The project generator previously declared the catalog as ordinary JSON, so Xcode copied it without compiling language bundles. It now uses `text.json.xcstrings`, derives project regions from the catalog, and includes a native resource regression test. The earlier French capture was rejected when its bundle language was English, even though its Foundation locale was French.

## Marketing scope

The ten sequences cover move-out organisation, outstanding checks, fixture observations, rental photos, condition notes, final meter readings, keys/access, tenancy documents, move-in/out comparisons and PDF evidence reports. Captions describe implemented functions without promising a deposit outcome, legal evidential status or search rankings. The report image discloses the paid LeaveWell Plus subscription. There are no invented reviews or customer records.

The 17 languages are English (U.K.), French, Spanish (Spain), German, Italian, Portuguese (Brazil), Dutch, Polish, Arabic, Hindi, Japanese, Korean, Simplified Chinese, Traditional Chinese, Turkish, Indonesian and Swedish. Full-app translation and independent native-speaker review remain outstanding. Quantity labels currently combine a count and the singular access-item type; this is a minor grammar limitation in some languages.

The captured app source tree is `aa01e6dc77eea0e798f9b65e40e2352a14a8a054` (`LeaveWell/` in capture commit `2ceac5f`; the subsequent release test-fixture commits retain that same app tree). Subsequent test-fixture fixes do not change that app tree. The source SDK and capture commit are also recorded per language in the native manifest.

## App Store draft upload

On 1 November 2026, all 170 exports were uploaded to their matching 17 iPhone Duo localization slots. Build 83 was selected in the version 1.0 draft, and partial-translation disclosures/review notes were saved. `asc-upload-receipts.json` records the verified counts and output hashes. The physical existing-account restore check remains pending; the draft was not resubmitted for review. See `docs/APP_STORE_DUO_UPLOAD_2026-11-01.txt` for the rollout record. This manual upload does not change the frozen screenshot ZIP or its delivery checksum.
