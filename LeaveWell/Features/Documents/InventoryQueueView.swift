import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct InventoryQueueView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    var opensImporter = false
    var opensPracticeDocument = false
    @State private var reader = InventoryReader()
    @State private var showingImporter = false
    @State private var importing = false
    @State private var presentedSource: Evidence?
    @State private var error: String?
    @State private var prompted = false

    var body: some View {
        List {
            if let record = store.record(caseID) {
                let checks = record.checkout?.inventoryChecks ?? []
                let pending = checks.filter { !record.inventoryCheckIsResolved($0) }
                Section {
                    Text(L("Turn entries from your move-in inventory into checks for handover."))
                    if let next = pending.first {
                        NavigationLink(L("Continue to the next check")) { InventoryObservationView(caseID: caseID, check: next) }
                    }
                }
                Section(L("Move-in documents")) {
                    Button(L("Import inventory"), systemImage: "doc.badge.plus") { showingImporter = true }.disabled(importing)
                    ForEach(record.evidence.filter { $0.kind == .document && $0.original != nil }) { source in
                        Button { presentedSource = source } label: { Label(source.label, systemImage: "doc.text") }
                    }
                    if importing { ProgressView(L("Opening inventory…")) }
                    if record.rooms.isEmpty {
                        Text(L("Add a room in property details before confirming checks.")).foregroundStyle(.secondary)
                    }
                }
                ForEach(record.rooms) { room in
                    let entries = checks.filter { $0.roomID == room.id }
                    if !entries.isEmpty {
                        Section(room.name) {
                            ForEach(entries) { entry in
                                NavigationLink { InventoryObservationView(caseID: caseID, check: entry) } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(entry.sourceText).font(.headline)
                                        Text(record.inventorySourceIsAvailable(entry) ? L(entry.state.title) : L("Source unavailable"))
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                if opensImporter || opensPracticeDocument {
                    NavigationLink(L("Continue to checkout workspace")) { CheckoutWorkspaceView(caseID: caseID) }
                }
            }
        }
        .navigationTitle(L("Move-in inventory checks"))
        .task {
            guard !prompted else { return }
            prompted = true
            if opensImporter { showingImporter = true }
            if opensPracticeDocument {
                presentedSource = store.record(caseID)?.evidence.first { $0.kind == .document }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf, .image]) { result in
            guard !importing else { return }
            importing = true
            Task {
                defer { importing = false }
                do {
                    let id = try await store.importInventory(result.get(), caseID: caseID, reader: reader)
                    presentedSource = store.record(caseID)?.evidence.first { $0.id == id }
                } catch is CancellationError {
                } catch { self.error = error.localizedDescription }
            }
        }
        .sheet(item: $presentedSource) { source in
            NavigationStack { InventorySourceView(caseID: caseID, source: source, reader: reader) }
        }
        .errorAlert($error)
    }
}

private struct InventorySourceView: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    let caseID: UUID
    let source: Evidence
    let reader: InventoryReader
    @State private var url: URL?
    @State private var number = 1
    @State private var count = 1
    @State private var page: InventoryPage?
    @State private var draft = ""
    @State private var roomID: UUID?
    @State private var saved = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            let layout = sizeClass == .regular && !typeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            layout {
                VStack(alignment: .leading, spacing: 12) {
                    if count > 1 {
                        Stepper(L("Page") + " \(number.formatted()) / \(count.formatted())", value: $number, in: 1...count)
                    }
                    InventoryPagePreview(page: page)
                }.frame(maxWidth: .infinity, alignment: .leading)
                editor.frame(maxWidth: .infinity, alignment: .leading)
            }.padding()
        }
        .navigationTitle(source.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        .task {
            do {
                guard let original = source.original else { throw VaultError.missingFile }
                let verified = try await store.vault.verifiedURL(for: original)
                count = try await reader.pageCount(verified)
                url = verified
            } catch { self.error = error.localizedDescription }
        }
        .task(id: PageRequest(url: url, number: number)) {
            guard let url else { return }
            let requested = number
            do {
                let result = try await reader.read(url, page: requested, suggest: true)
                guard !Task.isCancelled, requested == number else { return }
                page = result
            } catch is CancellationError {
            } catch { self.error = error.localizedDescription }
        }
        .onChange(of: number) { _, _ in page = nil; draft = ""; saved = false }
        .errorAlert($error)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Confirm an inventory entry")).font(.title2.bold())
            Text(L("Compare the suggested text with the page. Correct it or type an entry yourself.")).foregroundStyle(.secondary)
            if let page, !page.suggestions.isEmpty {
                ForEach(page.suggestions, id: \.self) { suggestion in
                    Button { draft = suggestion; saved = false } label: {
                        Label(suggestion, systemImage: "plus.circle").frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered)
                }
            }
            TextField(L("Text from the inventory"), text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...6)
            Picker(L("Room"), selection: $roomID) {
                Text(L("Select a room")).tag(UUID?.none)
                ForEach(store.record(caseID)?.rooms ?? []) { room in Text(room.name).tag(Optional(room.id)) }
            }
            Button(L("Add checkout check"), action: confirm).buttonStyle(PrimaryButton())
                .disabled(page == nil || roomID == nil || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if saved { Label(L("Added to the room checks"), systemImage: "checkmark.circle") }
        }
    }

    private func confirm() {
        guard let roomID, page != nil, let record = store.record(caseID) else { return }
        let text = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        let check = InventoryCheck(sourceID: source.id, page: number, roomID: roomID, sourceText: text)
        guard !text.isEmpty, record.inventorySourceIsAvailable(check) else { error = L("Source unavailable"); return }
        let duplicate = (record.checkout?.inventoryChecks ?? []).contains {
            $0.sourceID == check.sourceID && $0.page == check.page && $0.roomID == check.roomID && $0.sourceText == check.sourceText
        }
        if duplicate { error = L("This entry is already in the room checks."); return }
        do {
            try store.update(caseID, action: "Inventory check confirmed") { record in
                if record.checkout == nil { record.checkout = CheckoutSession() }
                var checks = record.checkout?.inventoryChecks ?? []
                checks.append(check)
                record.checkout?.inventoryChecks = checks
            }
            draft = ""
            saved = true
        } catch { self.error = error.localizedDescription }
    }

    private struct PageRequest: Equatable {
        let url: URL?
        let number: Int
    }
}

private struct InventoryPagePreview: View {
    let page: InventoryPage?
    var body: some View {
        if let page, let image = UIImage(data: page.preview) {
            Image(uiImage: image).resizable().scaledToFit()
                .accessibilityLabel(L("Inventory page image"))
        } else { ProgressView(L("Opening inventory…")) }
    }
}

private struct InventoryObservationView: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    let caseID: UUID
    @State private var draft: InventoryCheck
    @State private var page: InventoryPage?
    @State private var sourceError: String?
    @State private var error: String?
    @State private var capture: CaptureSelection?

    init(caseID: UUID, check: InventoryCheck) {
        self.caseID = caseID
        _draft = State(initialValue: check)
    }

    var body: some View {
        ScrollView {
            let layout = sizeClass == .regular && !typeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            layout {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Move-in inventory") + " · " + L("Page") + " " + draft.page.formatted()).font(.headline)
                    Text(draft.sourceText).font(.title3)
                    if let sourceError { Text(sourceError).foregroundStyle(.secondary) }
                    else { InventoryPagePreview(page: page) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if let record = store.record(caseID) { editor(record).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding()
        }.navigationTitle(L("Checkout observation"))
            .task {
                do {
                    guard let original = store.record(caseID)?.evidence.first(where: { $0.id == draft.sourceID })?.original else {
                        throw VaultError.missingFile
                    }
                    let url = try await store.vault.verifiedURL(for: original)
                    page = try await InventoryReader().read(url, page: draft.page, suggest: false)
                } catch is CancellationError {
                } catch { sourceError = error.localizedDescription }
            }
            .sheet(item: $capture) { EvidenceComposer(caseID: caseID, selection: $0) }
            .errorAlert($error)
    }

    private func editor(_ record: MoveCase) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(L("Checkout status"), selection: $draft.state) {
                ForEach(InventoryCheckState.allCases, id: \.self) { Text(L($0.title)).tag($0) }
            }
            TextField(L("What did you see, or why could you not check?"), text: $draft.observation, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(3...8)
            Button(L("Capture or import evidence"), systemImage: "camera") {
                capture = CaptureSelection(roomID: draft.roomID, label: L("Checkout observation"), kind: .photo)
            }
            ForEach(record.evidence.filter { $0.roomID == draft.roomID && [.photo, .audio, .note].contains($0.kind) }) { item in
                Toggle(item.label, isOn: Binding(get: { draft.evidenceIDs.contains(item.id) }, set: { selected in
                    if selected { draft.evidenceIDs.append(item.id) }
                    else { draft.evidenceIDs.removeAll { $0 == item.id } }
                }))
            }
            if draft.evidenceIDs.contains(where: { id in !record.evidence.contains { $0.id == id } }) {
                Button(L("Remove missing evidence links")) {
                    draft.evidenceIDs.removeAll { id in !record.evidence.contains { $0.id == id } }
                }
            }
            Button(L("Save checkout observation")) {
                guard draft.state == .awaitingCheck || record.inventoryCheckIsResolved(draft) else {
                    error = L("Add an observation or a reason before finishing this check.")
                    return
                }
                do {
                    try store.update(caseID, action: "Inventory observation saved") { record in
                        if let index = record.checkout?.inventoryChecks?.firstIndex(where: { $0.id == draft.id }) {
                            record.checkout?.inventoryChecks?[index] = draft
                        }
                    }
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }.buttonStyle(PrimaryButton())
            if sourceError != nil {
                Button(L("Remove checkout check"), role: .destructive) {
                    do {
                        try store.update(caseID, action: "Inventory check removed") {
                            $0.checkout?.inventoryChecks?.removeAll { $0.id == draft.id }
                        }
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
    }
}
