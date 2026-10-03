import SwiftUI

struct SettingsView: View {
    @Environment(CaseStore.self) private var store
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var share: SharePayload?
    @State private var deleting: MoveCase?
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        Form {
            Section(L("Privacy & security")) {
                Toggle(L("Lock with Face ID or device passcode"), isOn: $appLockEnabled)
                Text(L("Records and originals are stored on this device with iOS file protection. No tenancy data is sent to advertising or analytics services.")).font(.footnote).foregroundStyle(.secondary)
                Text(L("Cloud backup and co-tenant collaboration are not available in this build. Export a copy before changing devices. Losing this device may mean losing your records.")).font(.footnote).foregroundStyle(.secondary)
            }
            Section(L("Your data")) {
                Button(L("Export all records and original files")) {
                    Task {
                        busy = true; defer { busy = false }
                        do { share = SharePayload(urls: try await store.exportData()) } catch { self.error = error.localizedDescription }
                    }
                }.disabled(busy)
                if busy { ProgressView(L("Checking and exporting originals…")) }
                Text(L("The export contains a JSON record and original files. Save all items together. Original filenames in the JSON use an originals/ folder; place the exported media in that folder when archiving.")).font(.footnote).foregroundStyle(.secondary)
                ForEach(store.archive.cases) { record in
                    Button(L("Delete record") + " · " + record.nickname, role: .destructive) { deleting = record }
                }
            }
            Section(L("Language")) {
                Text(L("LeaveWell follows your device language. English is used where a reviewed translation is not available."))
                Button(L("Open iOS Settings")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            }
            Section(L("About LeaveWell")) {
                Text(L("Move out organised. Leave with the evidence."))
                Text(L("LeaveWell organises evidence. It does not make legal decisions.")).font(.footnote).foregroundStyle(.secondary)
                LabeledContent(L("Version"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
        }.navigationTitle(L("Settings")).sheet(item: $share) { ShareSheet(urls: $0.urls) }
            .confirmationDialog(L("Delete this record and all its evidence? This cannot be undone."), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button(L("Delete record"), role: .destructive) {
                    guard let id = deleting?.id else { return }
                    Task { do { try await store.deleteCase(id); try ExportWorkspace.clear() } catch { self.error = error.localizedDescription }; deleting = nil }
                }
            }.errorAlert($error)
    }
}
