import SwiftUI

struct EvidenceListView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    var documentsOnly = false
    @State private var query = ""
    @State private var selection: CaptureSelection?
    var body: some View {
        let items = store.record(caseID)?.search(query).filter { !documentsOnly || $0.kind == .document } ?? []
        List {
            if items.isEmpty { ContentUnavailableView(L("No evidence here yet"), systemImage: "doc.text.magnifyingglass", description: Text(L("Add a record or try a different search."))) }
            ForEach(items) { item in NavigationLink { EvidenceDetailView(caseID: caseID, evidenceID: item.id) } label: { EvidenceRow(item: item) } }
        }.navigationTitle(documentsOnly ? L("Document vault") : L("All evidence"))
            .searchable(text: $query, prompt: L("Search labels, notes and rooms"))
            .toolbar { Button { selection = CaptureSelection(label: documentsOnly ? "Original inventory" : "Other", kind: documentsOnly ? .document : .photo) } label: { Image(systemName: "plus").accessibilityLabel(L("Add evidence")) } }
            .sheet(item: $selection) { EvidenceComposer(caseID: caseID, selection: $0) }
    }
}

struct EvidenceRow: View {
    let item: Evidence
    var body: some View {
        HStack(spacing: 14) {
            SymbolTile(symbol: item.kind.symbol)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.label).font(.headline)
                Text(item.original?.capturedAt == nil && item.original?.origin == .imported ? L("Imported") : L("Recorded")).font(.caption).foregroundStyle(.secondary)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !item.includedInReport { Image(systemName: "eye.slash").foregroundStyle(.secondary).accessibilityLabel(L("Excluded from report")) }
        }.padding(.vertical, 5)
    }
}

extension EvidenceKind {
    var title: String { switch self { case .photo: L("Photo"); case .video: L("Video"); case .audio: L("Voice recording"); case .document: L("Document"); case .note: L("Text note") } }
    var symbol: String { switch self { case .photo: "photo"; case .video: "video"; case .audio: "waveform"; case .document: "doc"; case .note: "text.alignleft" } }
}
