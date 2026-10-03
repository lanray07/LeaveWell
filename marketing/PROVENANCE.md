# LeaveWell App Store creative

The ten compositions use real LeaveWell SwiftUI screens, captured by GitHub Actions on iOS Simulator. Screenshot data is fictional and labelled Demo. MarketingCapture is compiled only in Debug; Release contains no capture routes or sample records. Native captures are preserved under `marketing/captures`.

Lifestyle photography was generated with the built-in Codex Image Generation tool, not a remote API or CLI fallback. The app interfaces and factual copy were not generated into photographs. Typography, frames, safe margins and platform dimensions are exported deterministically by `scripts/export_marketing.py`.

## Final prompt set

- **lifestyle-home:** Candid woman renter in her early 30s packing a plain moving box beside a houseplant in a modest light UK rented flat. Relaxed focused expression, believable skin and hands, ivory walls, sage knit, warm afternoon window light. Subject lower-right with clean pale wall space above. No UI, words, logos, brands or promises.
- **lifestyle-keys:** Photorealistic natural editorial photograph for LeaveWell App Store marketing. Portrait. Candid hands returning two plain brass house keys with a navy fabric strap over a wooden kitchen worktop in a modest bright UK flat. Linen cloth, green plant and blurred moving box. Soft daylight, teal, cream and ochre palette. Handover in lower half; clean ivory wall above. Realistic anatomy and textures. No text, labels, brands, watermark, phone, UI, money, awards or promises.
- **demo-kitchen:** Photorealistic documentary condition photograph of a modest UK rental kitchen, ivory cupboards, oak worktop, grey tiled splashback, stainless sink, small plant, natural daylight and subtle ordinary wear. Landscape 3:2, coherent architecture, realistic material textures. No people, brands, text, phone, UI, labels or watermarks.
- **subscription-organised:** Warm quiet premium editorial still life. Deep teal paper folder slightly open with blank off-white sheets, two ordinary brass house keys on natural oak, ivory linen and subtle doorway shadow. Soft daylight, centered object cluster with safe margins. No words, numbers, logos, UI, money, prices, awards, crowns or certification claims.
- **subscription-next-chapter:** Photorealistic natural square premium editorial still life for LeaveWell. Small healthy plant in ceramic pot, closed plain teal notebook, and brass house keys in a linen tray, grouped centrally on an oak console. Entire main objects within central 70 percent. Ivory plaster, warm sage, blurred doorway, soft daylight and realistic textures. No text, branding, UI, money, prices, awards, badges, folders, app icon or promises.

## Export and listing notes

- iPhone: ten RGB PNGs, 1284 × 2778, for the 6.5-inch slot shown in App Store Connect.
- iPad: the same ten stories using native tablet interfaces, RGB PNGs, 2064 × 2752, for the 13-inch slot.
- Subscription artwork: two distinct RGB PNGs, exactly 1024 × 1024, with no plan names, prices or invented benefits.
- The subscription artwork is a promotional-image draft, not an App Review screenshot of a purchase flow. No paywall exists in the current edition. Product metadata and pricing require the owner's plan details; paid access must work before submitting a subscription.
- English U.K. is the only reviewed app language. No unreviewed translated listing is published.
- Search copy uses relevant renter, move-out, inventory, meter, handover and evidence vocabulary. No keyword search-volume or ranking claim is made.
- Saved metadata is in `app-store-en-GB.json`; asset dimensions and SHA-256 hashes are in `exports/manifest.json`.
- The app listing remains Prepare for Submission. Privacy answers are saved as a draft; Apple's Publish confirmation requires the developer to agree to an accuracy and legal-compliance statement. No review submission or release is performed.

Apple references: [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [promoted in-app purchase artwork](https://developer.apple.com/app-store/promoting-in-app-purchases/), [app privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).
