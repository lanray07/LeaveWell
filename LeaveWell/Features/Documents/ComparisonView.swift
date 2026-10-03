import SwiftUI
import QuickLook

struct ComparisonView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var moveInID: UUID?
    @State private var moveOutID: UUID?
    @State private var note = ""
    @State private var previewURL: URL?
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Text(L("Review your original inventory alongside the current evidence. Add your own factual observations.")).foregroundStyle(.secondary)
            }
            Section(L("Move-in")) {
                Picker(L("Inventory or photograph"), selection: $moveInID) {
                    Text(L("Select a record")).tag(UUID?.none)
                    ForEach(store.record(caseID)?.evidence.filter { $0.kind == .document || $0.kind == .photo } ?? []) { Text($0.label).tag(Optional($0.id)) }
                }
                previewButton(moveInID)
            }
            Section(L("Move-out")) {
                Picker(L("Current photograph"), selection: $moveOutID) {
                    Text(L("Select a record")).tag(UUID?.none)
                    ForEach(store.record(caseID)?.evidence.filter { $0.kind == .photo } ?? []) { Text($0.label).tag(Optional($0.id)) }
                }
                previewButton(moveOutID)
            }
            Section(L("Your observation")) {
                TextField(L("Describe what you can see"), text: $note, axis: .vertical).lineLimit(4...12)
                Button(L("Save comparison note")) {
                    Task {
                        do {
                            guard let record = store.record(caseID), let before = record.evidence.first(where: { $0.id == moveInID }), let after = record.evidence.first(where: { $0.id == moveOutID }) else { return }
                            let notes = L("Move-in") + ": " + before.reference + "\n" + L("Move-out") + ": " + after.reference + "\n\n" + note
                            let item = Evidence(roomID: after.roomID, kind: .note, label: L("Move-in vs Move-out"), notes: notes, contributor: record.tenant)
                            try await store.addEvidence(item, caseID: caseID); note = ""
                        } catch { self.error = error.localizedDescription }
                    }
                }.disabled(moveInID == nil || moveOutID == nil || moveInID == moveOutID || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.navigationTitle(L("Move-in vs Move-out")).quickLookPreview($previewURL).errorAlert($error)
    }
    @ViewBuilder private func previewButton(_ id: UUID?) -> some View {
        if let id, let original = store.record(caseID)?.evidence.first(where: { $0.id == id })?.original {
            Button(L("View original file")) { Task { do { previewURL = try await store.vault.verifiedURL(for: original) } catch { self.error = error.localizedDescription } } }
        }
    }
}
