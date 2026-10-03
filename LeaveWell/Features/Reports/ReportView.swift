import SwiftUI
import QuickLook

struct ReportView: View {
    @Environment(CaseStore.self) private var store
    @Environment(PurchaseService.self) private var purchases
    let caseID: UUID
    @State private var options = ReportOptions()
    @State private var url: URL?
    @State private var previewURL: URL?
    @State private var share: SharePayload?
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Form {
            if let record = store.record(caseID) {
                Section {
                    Label(L("An organised record, ready to share."), systemImage: "doc.richtext").font(.title2.bold())
                    Text(L("Your report includes the evidence you selected, room records, readings, access items and supporting documents.")).foregroundStyle(.secondary)
                    LabeledContent(L("Included evidence"), value: "\(record.evidence.filter(\.includedInReport).count)")
                    Text(L("Review your evidence before exporting. Anyone you share the PDF with can keep a copy.")).font(.footnote).foregroundStyle(.secondary)
                }
                Section(L("Sharing controls")) {
                    Toggle(L("Include landlord / agent contact"), isOn: $options.includeContactDetails)
                    Toggle(L("Include deposit details"), isOn: $options.includeDepositDetails)
                    Text(L("The property address, tenant name and contributor names appear in the report. Imported documents may contain private information.")).font(.footnote)
                }
                Section(L("Declaration")) {
                    Text(L("To the best of my knowledge, this record reflects the property and information I documented at the stated dates and times."))
                    Toggle(L("Include my declaration"), isOn: $options.declarationAccepted)
                }
                Section {
                    Text(L("PDF reports are included with LeaveWell Plus.")).font(.footnote).foregroundStyle(.secondary)
                    if !purchases.hasPlus {
                        NavigationLink(L("Explore LeaveWell Plus")) { PlusView() }
                    }
                    Button(L("Generate PDF report")) {
                        guard !busy else { return }
                        busy = true
                        Task {
                            defer { busy = false }
                            do {
                                try await purchases.requirePlus()
                                url = try await ReportService().generate(record: record, options: options, vault: store.vault)
                            }
                            catch { self.error = error.localizedDescription }
                        }
                    }.disabled(busy || !purchases.hasPlus)
                    if busy { ProgressView(L("Checking originals and preparing report…")) }
                    if let url {
                        Button(L("Preview report")) { previewURL = url }
                        Button(L("Share or save PDF")) { share = SharePayload(urls: [url]) }
                        Text(L("This PDF is a snapshot. Regenerate it after changing evidence or sharing controls.")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }.disabled(busy).navigationTitle(L("Your evidence report")).quickLookPreview($previewURL)
            .sheet(item: $share) { ShareSheet(urls: $0.urls) }.errorAlert($error)
            .onChange(of: options.includeContactDetails) { _, _ in url = nil }
            .onChange(of: options.includeDepositDetails) { _, _ in url = nil }
            .onChange(of: options.declarationAccepted) { _, _ in url = nil }
    }
}
