import SwiftUI
import QuickLook
import AVKit

struct EvidenceDetailView: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let caseID: UUID
    let evidenceID: UUID
    @State private var notes = ""
    @State private var label = ""
    @State private var condition = Condition.noIssue
    @State private var include = true
    @State private var loaded = false
    @State private var previewURL: URL?
    @State private var error: String?
    @State private var deleting = false
    @State private var confirmDelete = false
    private var item: Evidence? { store.record(caseID)?.evidence.first { $0.id == evidenceID } }
    var body: some View {
        Form {
            if let item {
                if let original = item.original {
                    Section(L("Original evidence")) {
                        Button { Task { do { previewURL = try await store.vault.verifiedURL(for: original) } catch { self.error = error.localizedDescription } } } label: { Label(L("View original file"), systemImage: item.kind.symbol) }
                        Text(original.originalName).font(.footnote)
                        if let captured = original.capturedAt { LabeledContent(L("Captured"), value: captured.formatted(date: .abbreviated, time: .standard)) }
                        else { LabeledContent(L("Captured"), value: L("Unknown")) }
                        if let imported = original.importedAt { LabeledContent(L("Imported"), value: imported.formatted(date: .abbreviated, time: .standard)) }
                        LabeledContent(L("File created"), value: original.createdAt.formatted(date: .abbreviated, time: .standard))
                        Text(L("SHA-256") + "\n" + original.sha256).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                Section(L("Editable description")) {
                    TextField(L("Label"), text: $label)
                    TextField(L("Your notes"), text: $notes, axis: .vertical).lineLimit(4...12)
                    Picker(L("Condition"), selection: $condition) { ForEach(Condition.allCases, id: \.self) { Text($0.title).tag($0) } }
                    Toggle(L("Include in report"), isOn: $include)
                    Button(L("Save changes")) {
                        do { try store.update(caseID, action: "Description updated", detail: item.reference) { record in
                            guard let index = record.evidence.firstIndex(where: { $0.id == evidenceID }) else { return }
                            record.evidence[index].notes = notes; record.evidence[index].label = label
                            record.evidence[index].condition = condition; record.evidence[index].includedInReport = include
                            record.evidence[index].updatedAt = Date()
                        }; dismiss() } catch { self.error = error.localizedDescription }
                    }.disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !item.transcript.isEmpty { Section(L("Original transcription")) { Text(item.transcript); Text(L("Machine transcription; review against the recording.")).font(.caption).foregroundStyle(.secondary) } }
                Section(L("Record information")) {
                    Text(item.reference).font(.caption.monospaced()).textSelection(.enabled)
                    LabeledContent(L("Created"), value: item.createdAt.formatted(date: .abbreviated, time: .standard))
                    LabeledContent(L("Updated"), value: item.updatedAt.formatted(date: .abbreviated, time: .standard))
                    LabeledContent(L("Contributor"), value: item.contributor)
                    Label(L("Saved on device"), systemImage: "checkmark.shield")
                }
                Section { Button(L("Delete evidence"), role: .destructive) { confirmDelete = true }.disabled(deleting) }
            }
        }.navigationTitle(L("Evidence details")).quickLookPreview($previewURL)
            .task { if !loaded, let item { label = item.label; notes = item.notes; condition = item.condition; include = item.includedInReport; loaded = true } }
            .confirmationDialog(L("Delete this evidence and its original file?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L("Delete evidence"), role: .destructive) { Task { deleting = true; defer { deleting = false }; do { if let item { try await store.deleteEvidence(item, caseID: caseID) }; dismiss() } catch { self.error = error.localizedDescription } } }
            }.errorAlert($error)
    }
}
