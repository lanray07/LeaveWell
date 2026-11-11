# LeaveWell 1.0 (90) device verification

11 November 2026. TestFlight on the owner's iPad running iPadOS 26.7.1. The existing Apple Account and LeaveWell records stayed in place.

| Check | Observed result |
| --- | --- |
| App lock | Touch ID returned to the records. A later lock interrupted editing, and the entered text remained after unlocking. |
| Restore Purchases with an active subscription | The app confirmed “LeaveWell Plus is active” after Restore Purchases was tapped. No Apple authentication or new purchase occurred. |
| Restore when StoreKit has no active entitlement | Open. An active verified entitlement was already present, so build 90 returned before calling `AppStore.sync()`. Build 83 had previously reported an Apple sync error on this path. The simulated StoreKit cases passed in CI, and this session did not reproduce the physical-device recovery case. |
| Practice inventory | The fictional PDF opened and extracted text, including the sink entry. One Kitchen check was saved using the document heading on page 1. The checkout observation editor showed the source page alongside the editable check in landscape. |
| Checkout observation | Saved the status “Checked at move-out” and the note “Fictional inventory page one reviewed at handover.” The saved status appeared in the inventory queue. |
| PDF report | Generated and opened a Move-Out Condition Record with the active Plus entitlement. Search returned one match for the exact observation phrase “reviewed at handover.” The handover review identified six outstanding areas for the fictional case. |

The source-entry sheet in landscape required scrolling past the PDF to reach its controls. The physical session covered a fictional practice case using the owner's account. Build 90's automated results are in the [GitHub release run](https://github.com/lanray07/LeaveWell/actions/runs/43010808244).

Resubmission remains pending on verification of the existing-account recovery path. The refreshed storefront assets use real simulator screens and fictional records. The new inventory screens still display some English text in non-English locales.
