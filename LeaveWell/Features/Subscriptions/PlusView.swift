import SwiftUI
import StoreKit

struct PlusView: View {
    @Environment(PurchaseService.self) private var purchases
    @State private var showManagement = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("LeaveWell Plus", systemImage: "doc.richtext").font(.headline).foregroundStyle(Theme.accent)
                Text(L("Feel ready for your next move.")).font(.largeTitle.bold())
                Text(L("Turn your rental records into a clear PDF, from move-in checks to the final handover.")).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    Label(L("Unlimited PDF evidence reports"), systemImage: "doc.text")
                    Label(L("Regenerate reports as your records change"), systemImage: "arrow.clockwise")
                    Label(L("Choose evidence and control contact details"), systemImage: "checklist")
                    Label(L("Preview, save and share your reports"), systemImage: "square.and.arrow.up")
                }.padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                if purchases.hasPlus {
                    Label(L("LeaveWell Plus is active"), systemImage: "checkmark.seal.fill").foregroundStyle(Theme.accent)
                    Button(L("Manage subscription")) { showManagement = true }.buttonStyle(PrimaryButton())
                } else {
                    Text(L("Choose your billing period")).font(.headline)
                    Text(L("Both plans include the same Plus features. The annual plan is billed once a year.")).font(.footnote).foregroundStyle(.secondary)
                    if purchases.loading { ProgressView(L("Loading subscription prices…")) }
                    ForEach(purchases.products, id: \.id) { product in
                        Button { Task { await purchases.purchase(product) } } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.displayName).font(.headline)
                                Text(product.displayPrice + " / " + (product.id == PlusPlan.monthly ? L("month") : L("year"))).font(.title3.bold())
                                Text(product.id == PlusPlan.monthly ? L("Billed monthly. Renews automatically.") : L("Billed annually. Renews automatically.")).font(.footnote)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
                        }.buttonStyle(.bordered).disabled(purchases.purchasing)
                    }
                    if purchases.products.count < PlusPlan.productIDs.count && !purchases.loading {
                        Button(L("Reload plans")) { Task { await purchases.load() } }
                    }
                }
                if purchases.purchasing { ProgressView(L("Waiting for the App Store…")) }
                if let message = purchases.message { Text(message).font(.callout).accessibilityIdentifier("purchaseMessage") }
                if let error = purchases.errorMessage { Text(error).font(.callout).foregroundStyle(.red).accessibilityIdentifier("purchaseError") }
                Button(L("Restore purchases")) { Task { await purchases.restore() } }.disabled(purchases.purchasing)
                Text(L("Payment is charged to your Apple Account at confirmation. Your subscription renews automatically unless cancelled at least 24 hours before the current period ends. Renewal is charged within 24 hours before the period ends. Manage or cancel in App Store subscription settings.")).font(.footnote).foregroundStyle(.secondary)
                Text(L("Photos, notes, checklists, access to your records and export of original files remain free. If Plus ends, your records and previously saved PDFs remain yours. Plus does not include cloud storage or legal advice.")).font(.footnote).foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    Link(L("Privacy policy"), destination: PlusPlan.privacyURL)
                    Link(L("Terms of use"), destination: PlusPlan.termsURL)
                }.font(.footnote)
            }.padding(24).frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity)
        }.navigationTitle("LeaveWell Plus").navigationBarTitleDisplayMode(.inline)
            .task { await purchases.load() }
            .manageSubscriptionsSheet(isPresented: $showManagement)
    }
}
