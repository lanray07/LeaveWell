# LeaveWell App Store pack

Prepared and saved in App Store Connect on 3 October 2026 for app `6818834817`, English (U.K.), iOS version 1.0.

## Finished assets

- [iPhone gallery](exports/iphone-6.5/review-board.html): ten 1284 × 2778 RGB PNGs, uploaded to the 6.5-inch slot in order 01–10.
- [iPad gallery](exports/ipad-13/review-board.html): ten 2064 × 2752 RGB PNGs, uploaded to the 13-inch slot in order 01–10.
- [Subscription artwork](exports/subscriptions): two distinct 1024 × 1024 RGB promotional-image drafts. These have no product names, prices or unsupported benefit claims.
- [Listing copy](app-store-en-GB.json), [privacy policy](privacy.md), [final prompts and provenance](PROVENANCE.md), and [export dimensions and hashes](exports/manifest.json).

The native interfaces were captured from the real Debug app by [GitHub Actions run 37143778673](https://github.com/lanray07/LeaveWell/actions/runs/37143778673). Both device-family jobs succeeded. All ten compositions for each device family were visually inspected. Fictional records are labelled Demo; capture routes are excluded from Release. Lifestyle photographs use the built-in ImageGen tool.

## App Store Connect form status

Saved: app name and subtitle, primary and secondary categories, promotional text, description, keywords, support and marketing URLs, privacy policy and choices URLs, reviewer notes, age questionnaire (4+), and content-rights response. Existing review contact details, free pricing and availability were preserved. Screenshot uploads are complete and ordered for both device families.

The Data Not Collected privacy response remains a draft. Apple's Publish action includes an accuracy and legal-compliance agreement and needs action-time confirmation from the owner before acceptance.

No subscription group or product is configured. The owner must provide names, billing periods, prices and paid benefits, and working paid access must be implemented before a subscription can be submitted. The supplied artworks are ready for that future configuration; they are not screenshots of an existing paywall.

The listing remains Prepare for Submission. No build has been uploaded or selected for version 1.0, and no App Review submission or release was made.

## Reproduce

Download the two native-capture artifacts into `marketing/captures/iphone` and `marketing/captures/ipad`, then run `python scripts/export_marketing.py --raw marketing/captures` on Windows with Pillow and Segoe UI installed. This produces deterministic typography and platform dimensions while retaining native screen proportions. The preview sheets are inspection aids, not upload assets.
