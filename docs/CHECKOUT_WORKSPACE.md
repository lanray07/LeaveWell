# Connected checkout workspace

This change replaces the property landing screen with a connected checkout workflow. Previously, users assembled room records, checklist ticks, comparisons and handover details through separate tools. A checkout session now connects documented fixture checks, linked before/after evidence and a final completeness review.

## Reviewer walkthrough

1. Create or open a property and choose **Start checkout**. Existing properties and their evidence remain available through **All record tools**.
2. Open a room. For each fixture, record its checked condition, a condition to explain, or a reason it does not apply. Link existing room evidence or capture/import evidence from the fixture screen. A changed condition needs both an observation and linked evidence.
3. Open the comparison board. Select a move-in photo/document and a distinct move-out photo, inspect them together, and save a factual observation. The pair retains references to the original records. Deleted sources are flagged for repair.
4. Set the handover scope. Add confirmed final meter readings, or record why a meter does not apply. Confirm the access inventory and record each item's actual handover date, quantity, recipient and method.
5. Open the final review. Follow missing-detail links to the relevant records. Save a review checkpoint once all checks are complete. Editing case content makes that checkpoint stale.
6. Export a report with an active LeaveWell Plus entitlement. The PDF includes the review state, outstanding details, applicable fixture observations and selected linked comparisons. Excluding a comparison source also excludes its paired observation. Partial reports remain possible and show incomplete checks.

The checkpoint is a saved content comparison, not a signature, independent inspection, legal certification or guarantee of a deposit outcome. Existing record exports and subscription behavior are preserved.

## Evidence and validation

- Core tests cover old-archive compatibility, documented fixture requirements, incomplete handovers, missing comparison sources and checkpoint persistence/invalidation, including stable encoding of sets.
- An iOS PDF regression checks the review section, linked observations and source-exclusion behavior. It produces `LeaveWell-checkout-package.pdf` for inspection.
- Debug capture routes include the new workspace, room walkthrough, handover review and evidence pair on iPhone and iPad. These use fictional demonstration records.
- GitHub Actions runs Xcode compilation, core/service tests and StoreKit lifecycle tests before signed archive export and App Store Connect upload.

## Before another App Review submission

Verify the uploaded build on a physical device, including an existing saved property, a full new checkout, interrupted/reopened work, excluded report sources and subscription restore. Gather feedback from independent consenting renters; owner testing should be described separately. Refresh store screenshots and review notes to demonstrate these workflows. Do not represent these changes or successful technical checks as assurance of approval under guideline 4.3.
