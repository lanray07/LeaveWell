import SwiftUI

struct RoomView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    let roomID: UUID
    @State private var selection: CaptureSelection?
    @State private var error: String?
    var body: some View {
        Group {
            if let record = store.record(caseID), let room = record.rooms.first(where: { $0.id == roomID }) {
                List {
                    Section {
                        Text(L("Start with the whole room")).font(.title2.bold())
                        Text(L("Capture a wide photograph from the doorway. Then work through the details below.")).foregroundStyle(.secondary)
                        ProgressView(value: room.progress)
                    }
                    Section(L("Guided walkthrough")) {
                        ForEach(room.items, id: \.self) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(L(item)).font(.headline); Spacer()
                                    if room.reviewedItems.contains(item) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).accessibilityLabel(L("Reviewed")) }
                                }
                                HStack {
                                    Button(L("Add evidence")) { selection = CaptureSelection(roomID: room.id, label: item, kind: .photo) }.buttonStyle(.bordered)
                                    Spacer()
                                    Button(room.reviewedItems.contains(item) ? L("Undo review") : L("Mark reviewed")) {
                                        do { try store.update(caseID, action: "Room checklist updated", detail: room.name + " · " + L(item)) { record in
                                            guard let index = record.rooms.firstIndex(where: { $0.id == roomID }) else { return }
                                            if record.rooms[index].reviewedItems.contains(item) { record.rooms[index].reviewedItems.remove(item) }
                                            else { record.rooms[index].reviewedItems.insert(item) }
                                        } } catch { self.error = error.localizedDescription }
                                    }.font(.caption).frame(minHeight: 44).buttonStyle(.borderless)
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                    Section(L("Room records")) {
                        ForEach(record.evidence(in: room).sorted { $0.createdAt > $1.createdAt }) { item in
                            NavigationLink { EvidenceDetailView(caseID: caseID, evidenceID: item.id) } label: { EvidenceRow(item: item) }
                        }
                        Button(L("Add a room note")) { selection = CaptureSelection(roomID: room.id, label: "Room note", kind: .note) }
                    }
                }.navigationTitle(room.name)
            }
        }.sheet(item: $selection) { EvidenceComposer(caseID: caseID, selection: $0) }.errorAlert($error)
    }
}

struct CaptureSelection: Identifiable {
    let id = UUID()
    var roomID: UUID?
    var label: String
    var kind: EvidenceKind
}
