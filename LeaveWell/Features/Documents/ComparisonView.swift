import SwiftUI
import QuickLook
import PDFKit
import ImageIO

struct ComparisonView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var beforeID: UUID?
    @State private var afterID: UUID?
    @State private var observation = ""
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        Form {
            if let record = store.record(caseID) {
                Section {
                    Text(L("Keep both sides of the story")).font(.title2.bold())
                    Text(L("Pair an original inventory or move-in photograph with a current photograph. Write your own observation; LeaveWell does not assess damage or decide responsibility."))
                }
                Section(L("Choose the evidence pair")) {
                    Picker(L("Move-in inventory or photograph"), selection: $beforeID) {
                        Text(L("Select a record")).tag(UUID?.none)
                        ForEach(record.evidence.filter { $0.kind == .document || $0.kind == .photo }) { Text($0.label).tag(Optional($0.id)) }
                    }
                    Picker(L("Move-out photograph"), selection: $afterID) {
                        Text(L("Select a record")).tag(UUID?.none)
                        ForEach(record.evidence.filter { $0.kind == .photo && $0.id != beforeID }) { Text($0.label).tag(Optional($0.id)) }
                    }
                    EvidencePairView(record: record, beforeID: beforeID, afterID: afterID)
                }
                Section(L("Factual observation")) {
                    TextField(L("Describe the visible difference or unchanged condition"), text: $observation, axis: .vertical).lineLimit(4...12)
                    Button(L("Save linked comparison")) { save() }
                        .disabled(beforeID == nil || afterID == nil || beforeID == afterID || observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if saved { Label(L("Comparison saved to this property"), systemImage: "checkmark.circle").font(.footnote) }
                }
                Section(L("Saved evidence pairs")) {
                    if record.checkout?.comparisons.isEmpty != false { Text(L("No evidence pairs saved yet. Comparisons are optional when no move-in evidence is available.")).font(.footnote) }
                    ForEach(record.checkout?.comparisons ?? []) { comparison in
                        NavigationLink { ComparisonDetailView(caseID: caseID, comparisonID: comparison.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(comparison.observation).lineLimit(3)
                                Text(comparison.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                if !record.validComparison(comparison) { Label(L("Linked evidence needs attention"), systemImage: "exclamationmark.triangle").font(.caption) }
                            }
                        }
                    }
                    NavigationLink(L("Import inventory or inspect older comparison notes")) { EvidenceListView(caseID: caseID) }
                }
            }
        }.navigationTitle(L("Evidence comparison board")).errorAlert($error)
    }
    private func save() {
        guard let beforeID, let afterID else { return }
        let value = EvidenceComparison(beforeID: beforeID, afterID: afterID, observation: observation)
        guard store.record(caseID)?.validComparison(value) == true else { error = L("Select two existing records and add an observation."); return }
        do {
            try store.update(caseID, action: "Evidence pair saved") { record in
                if record.checkout == nil { record.checkout = CheckoutSession() }
                record.checkout?.comparisons.append(value)
            }
            observation = ""; self.beforeID = nil; self.afterID = nil; saved = true
        } catch { self.error = error.localizedDescription }
    }
}

struct EvidencePairView: View {
    let record: MoveCase
    let beforeID: UUID?
    let afterID: UUID?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if typeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 16) { before; after } }
        else { HStack(alignment: .top, spacing: 12) { before; after } }
    }
    private var before: some View { EvidencePairCard(title: L("Move-in"), item: record.evidence.first { $0.id == beforeID }) }
    private var after: some View { EvidencePairCard(title: L("Move-out"), item: record.evidence.first { $0.id == afterID }) }
}

struct EvidencePairCard: View {
    @Environment(CaseStore.self) private var store
    let title: String
    let item: Evidence?
    @State private var image: UIImage?
    @State private var previewURL: URL?
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let image { Image(uiImage: image).resizable().scaledToFit().frame(height: 150).frame(maxWidth: .infinity).accessibilityLabel(item?.label ?? title) }
            else { Image(systemName: "doc.viewfinder").font(.largeTitle).frame(height: 150).frame(maxWidth: .infinity).accessibilityLabel(L("Select evidence or open the original")) }
            if let item {
                Text(item.label).font(.subheadline)
                Text(item.reference).font(.caption2.monospaced()).textSelection(.enabled)
                Text(item.original?.capturedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? L("Capture time unknown")).font(.caption).foregroundStyle(.secondary)
                if let original = item.original {
                    Button(L("Open original")) { Task { do { previewURL = try await store.vault.verifiedURL(for: original) } catch { self.error = error.localizedDescription } } }.font(.caption)
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }.frame(maxWidth: .infinity, alignment: .topLeading).quickLookPreview($previewURL)
            .task(id: item?.id) {
                image = nil; error = nil
                guard let original = item?.original else { return }
                do {
                    let url = try await store.vault.verifiedURL(for: original)
                    try Task.checkCancellation()
                    if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                       let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 800] as CFDictionary) {
                        image = UIImage(cgImage: thumbnail)
                    } else if let page = PDFDocument(url: url)?.page(at: 0) {
                        image = page.thumbnail(of: CGSize(width: 400, height: 500), for: .mediaBox)
                    }
                } catch is CancellationError { }
                catch { self.error = error.localizedDescription }
            }
    }
}

struct ComparisonDetailView: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let caseID: UUID
    let comparisonID: UUID
    @State private var observation = ""
    @State private var include = true
    @State private var loaded = false
    @State private var removing = false
    @State private var error: String?
    var body: some View {
        Form {
            if let record = store.record(caseID), let pair = record.checkout?.comparisons.first(where: { $0.id == comparisonID }) {
                Section { EvidencePairView(record: record, beforeID: pair.beforeID, afterID: pair.afterID) }
                Section(L("Your observation")) {
                    TextField(L("Factual observation"), text: $observation, axis: .vertical).lineLimit(4...12)
                    Toggle(L("Include comparison in report"), isOn: $include)
                    Text(L("The observation is exported only when both linked records are also included. Excluding either record excludes the comparison from the PDF.")).font(.footnote)
                    Button(L("Save changes")) {
                        do { try store.update(caseID, action: "Evidence pair updated") { record in
                            guard let index = record.checkout?.comparisons.firstIndex(where: { $0.id == comparisonID }) else { return }
                            record.checkout?.comparisons[index].observation = observation
                            record.checkout?.comparisons[index].includedInReport = include
                        }; dismiss() } catch { self.error = error.localizedDescription }
                    }.disabled(observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button(L("Remove comparison"), role: .destructive) { removing = true }
                    Text(L("Removing a pair keeps its original evidence records.")).font(.footnote)
                }
            }
        }.navigationTitle(L("Linked comparison")).errorAlert($error)
            .task { if !loaded, let pair = store.record(caseID)?.checkout?.comparisons.first(where: { $0.id == comparisonID }) { observation = pair.observation; include = pair.includedInReport; loaded = true } }
            .confirmationDialog(L("Remove this comparison?"), isPresented: $removing, titleVisibility: .visible) {
                Button(L("Remove comparison"), role: .destructive) {
                    do { try store.update(caseID, action: "Evidence pair removed") { $0.checkout?.comparisons.removeAll { $0.id == comparisonID } }; dismiss() }
                    catch { self.error = error.localizedDescription }
                }
            }
    }
}
