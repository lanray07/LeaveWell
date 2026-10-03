# LeaveWell App Store pack

Prepared and saved in App Store Connect on 3 October 2026 for app `6818834817`, English (U.K.), iOS version 1.0.

## Finished assets

- [iPhone gallery](exports/iphone-6.5/review-board.html): ten 1284 × 2778 RGB PNGs, uploaded to the 6.5-inch slot in order 01–10.
- [iPad gallery](exports/ipad-13/review-board.html): ten 2064 × 2752 RGB PNGs, uploaded to the 13-inch slot in order 01–10.
- [Subscription artwork](exports/subscriptions): two distinct 1024 × 1024 RGB subscription images, uploaded to the matching Plus products. These have no product names, prices or unsupported benefit claims.
- [Listing copy](app-store-en-GB.json), [privacy policy](privacy.md), [final prompts and provenance](PROVENANCE.md), and [export dimensions and hashes](exports/manifest.json).

The native interfaces were captured from the real Debug app by [GitHub Actions run 37143778673](https://github.com/lanray07/LeaveWell/actions/runs/37143778673). Both device-family jobs succeeded. PDF report views were refreshed by run 37148975501 for the new Plus access controls. All ten compositions for each device family were visually inspected. Fictional records are labelled Demo; capture routes are excluded from Release. Lifestyle photographs use the built-in ImageGen tool.

## App Store Connect form status

Saved: app name and subtitle, primary and secondary categories, promotional text, description, keywords, support and marketing URLs, privacy policy and choices URLs, reviewer notes, age questionnaire (4+), and content-rights response. Existing review contact details, free pricing and availability were preserved. Screenshot uploads are complete and ordered for both device families.

The Data Not Collected privacy response was published on 3 October 2026 after the owner explicitly approved Apple's accuracy and legal-compliance declaration. App Store Connect confirmed the published status.

LeaveWell Plus is configured in group 22437667. Monthly (com.LeaveWell.app.plus.monthly) is £2.99/month in the UK; Annual (com.LeaveWell.app.plus.annual) is £19.99/year billed upfront. Both are service level 1 with identical unlimited PDF report features. Apple equalises other regional prices. Product details are recorded in subscriptions.json. Purchase/restoration/manage UX and verified active entitlement checks are implemented; final build/test and App Review attachment status are recorded in release-status.json. No live purchases were made.

Version **1.0 (40)** passed validation, signing and upload in [run 37154369603](https://github.com/lanray07/LeaveWell/actions/runs/37154369603). Apple processed the build and it is selected in a draft with the Plus group, Monthly and Annual products: **Items Ready to Submit (4)**. The app, group and both products are **Ready for Review**. All 32 automated tests passed: seven core, fourteen iOS service, five localization and six real StoreKit lifecycle tests. StoreKit tests run on iOS 18.5 because of the Apple-documented iOS 26.5 simulator defect; the release uses Xcode 26.6 and the current SDK. The [actual purchase review screen](review/LeaveWell-Plus-purchase-review.png) shows UK StoreKit test prices and is attached to both products. No live purchase, final App Review submission or release was made. Physical-device Apple sandbox QA and the additional capabilities in docs/RELEASE.md remain separate release requirements.

The pre-submission review fixed app-lock/modal/accessibility privacy, microphone cancellation and note preservation, import/save races, reminder rescheduling and PDF completeness. See [the review report](../docs/PRE_SUBMISSION_REVIEW.md) and [draft preparation run](https://github.com/lanray07/LeaveWell/actions/runs/37156674257).

## Reproduce

Download the two native-capture artifacts into `marketing/captures/iphone` and `marketing/captures/ipad`, then run `python scripts/export_marketing.py --raw marketing/captures` on Windows with Pillow and Segoe UI installed. This produces deterministic typography and platform dimensions while retaining native screen proportions. The preview sheets are inspection aids, not upload assets.
