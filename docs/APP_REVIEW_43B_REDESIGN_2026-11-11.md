# LeaveWell product redesign after App Review 4.3(b)

11 November 2026 · iOS 1.0, build 83

Apple’s latest notice identifies design, content, and concept under 4.3(b) and applies Extended Review. It does not identify a particular screen, competing app, or technical defect. The product changes below are a response to the notice and the source audit. Their effectiveness still needs to be tested with renters.

## Build 83 baseline

Home opens with general move-out copy and a property list. First launch presents four introductory pages before the user can start a record. The existing checkout workspace tracks fixture checks, evidence pairings, readings, access handover, review checkpoints, and reports. A manually paired comparison is already supported. Those are foundations for the redesign.

Guided inspections, comparisons, and report exports are established features. RentCheck offers guided inspections and reports. InventoryBase and MoveCheck show move-in and move-out comparisons. The proposed workflow therefore focuses on how a renter turns an inventory they already received into a set of specific checkout tasks.

- [RentCheck App Store listing](https://apps.apple.com/us/app/rentcheck/id1134017691)
- [InventoryBase checkout workflow](https://support.inventorybase.com/en/articles/3491276-conducting-check-out-inspections)
- [MoveCheck inspection workflow](https://www.getmovecheck.com/)
- [Apple App Review Guidelines, 4.3](https://developer.apple.com/app-store/review/guidelines/#spam)

## Product experience

A renter imports the inventory they were given, confirms which entries matter at handover, and leaves with a record linking each observation to its original source and any current evidence. The same journey supports a renter who has photos, a scanned inventory, or no usable move-in record.

1. Start from an inventory. Offer import, a clearly labelled fictional walkthrough, and a path to start without an inventory on the opening screen. Extract selectable PDF text first. Offer on-device OCR for scanned pages and manual entry if extraction yields nothing. Show the original page beside each suggested entry and require confirmation before it becomes a checkout item.
2. Show what to check next. Make each confirmed entry actionable from a room queue. Show the source text and page when the renter records an observation. Support a photo, typed note, or existing audio note and distinguish entries awaiting evidence, entries the renter has checked, and entries they cannot verify. Preserve the reason and any attachments.
3. Review what will leave the device. Present unresolved entries and the evidence selected for sharing before export. A report entry should identify its source page and the linked checkout observation. If the source is excluded from export, omit its dependent comparison. Describe renter observations as observations and preserve original files separately from any extracted text or edits.

The proposed differentiator is this continuous workflow from a renter's existing document to a traceable handover record. The research establishes overlap in individual features. It does not establish market exclusivity.

## Implementation and verification

- Reuse the document vault, room records, linked evidence, checkout checkpoint, and report renderer. Add inventory entry records with a stable document reference, page reference, confirmed text, and explicit review state. Older cases should open without data conversion or a forced re-import.
- Build an iPhone flow with a clear next action and an iPad workspace where the original document and checkout entry can be inspected together. Keep the same actions available through VoiceOver and at accessibility text sizes. Support a typed alternative wherever voice or OCR is unavailable.
- Verify first launch through handover with a text PDF, a scanned PDF, and no inventory. Check interrupted import, unsupported files, duplicate imports, correcting OCR, excluding sources, reopening saved work, and upgrading an existing record. Confirm that the fictional sample is clearly identified and that its records do not mix with the renter's real property.
- Use GitHub Actions for the next build and TestFlight for device verification. Ask representative renters to try importing an inventory and finishing the first checkout item without prompting. Record what they struggled with and the changes made in response. Owner testing can validate device behaviour separately.
- Build 83 verified an active Plus entitlement and generated a PDF on the owner iPad. Account sync with no active entitlement returned an error. Keep that distinction in payment QA and retest the missing-entitlement recovery path separately.
- Capture the updated flow from the release candidate, then write reviewer steps that begin with the fictional sample and show the source-to-report path. Check localized UI, screenshots, and store claims against what that candidate actually contains.

The next submission should contain the implemented journey and evidence from the tested build. The product proposal has not yet been implemented or validated.
