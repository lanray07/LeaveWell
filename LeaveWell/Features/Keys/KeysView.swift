import SwiftUI

struct KeysView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var adding = false
    @State private var capture: CaptureSelection?
    var body: some View {
        List {
            Section { Text(L("Record each access item and who received it. Only mark handover when it has happened.")).foregroundStyle(.secondary) }
            ForEach(store.record(caseID)?.accessItems ?? []) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(item.quantity) " + L(item.type), systemImage: "key").font(.headline)
                    if let date = item.handedOverAt { Text(L("Handed over") + " · " + date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(Theme.accent) }
                    else { Text(L("Handover not recorded")).foregroundStyle(.secondary) }
                    if !item.recipient.isEmpty { Text(L("Recipient") + ": " + item.recipient) }
                    if !item.method.isEmpty { Text(item.method).font(.subheadline) }
                    if !item.notes.isEmpty { Text(item.notes) }
                    if let id = item.evidenceID { NavigationLink(L("View access item evidence")) { EvidenceDetailView(caseID: caseID, evidenceID: id) } }
                }.padding(.vertical, 8)
            }
            Button(L("Add access item photograph")) { capture = CaptureSelection(label: "Keys and fobs", kind: .photo) }
        }.navigationTitle(L("Keys & access"))
            .toolbar { Button(L("Add item")) { adding = true } }
            .sheet(isPresented: $adding) { KeyEditor(caseID: caseID) }
            .sheet(item: $capture) { EvidenceComposer(caseID: caseID, selection: $0) }
    }
}

struct KeyEditor: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let caseID: UUID
    @State private var type = "Front door key"
    @State private var custom = ""
    @State private var quantity = 1
    @State private var method = ""
    @State private var recipient = ""
    @State private var handedOver = false
    @State private var confirmed = false
    @State private var date = Date()
    @State private var notes = ""
    @State private var evidenceID: UUID?
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var voice = VoiceService()
    var body: some View {
        NavigationStack {
            Form {
                Section(L("Access item")) {
                    Picker(L("Type"), selection: $type) { ForEach(["Front door key", "Back door key", "Mailbox key", "Building fob", "Garage remote", "Parking permit", "Window key", "Other"], id: \.self) { Text(L($0)).tag($0) } }
                    if type == "Other" { TextField(L("Item name"), text: $custom) }
                    Stepper(L("Quantity") + " · \(quantity)", value: $quantity, in: 1...100)
                    Picker(L("Photograph"), selection: $evidenceID) {
                        Text(L("No photograph selected")).tag(UUID?.none)
                        ForEach(store.record(caseID)?.evidence.filter { $0.kind == .photo } ?? []) { Text($0.label).tag(Optional($0.id)) }
                    }
                }
                Section(L("Handover")) {
                    Toggle(L("Handed over"), isOn: $handedOver)
                    TextField(L("Handover method"), text: $method)
                    TextField(L("Recipient"), text: $recipient)
                    if handedOver { DatePicker(L("Handed over at"), selection: $date) }
                    TextField(L("Notes"), text: $notes, axis: .vertical)
                    Button(voice.recording ? L("Stop and transcribe") : L("Record a voice note")) { Task { if voice.recording { await voice.stopAndTranscribe(); notes = voice.transcript; confirmed = false } else { await voice.start() } } }.disabled(voice.starting || voice.processing)
                    if let message = voice.error { Text(message).font(.footnote) }
                    Toggle(L("I have reviewed these details"), isOn: $confirmed)
                }
            }.navigationTitle(L("Add access item"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L("Save")) {
                        do {
                            let item = AccessItem(type: type == "Other" ? custom : type, quantity: quantity, method: method, recipient: recipient, handedOverAt: handedOver ? date : nil, notes: notes, evidenceID: evidenceID)
                            try store.update(caseID, action: handedOver ? "Key handover recorded" : "Access item recorded", detail: L(item.type)) { $0.accessItems.append(item) }; dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(!confirmed || voice.starting || voice.recording || voice.processing || (type == "Other" && custom.isEmpty) || (handedOver && recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) }
                }.onChange(of: scenePhase) { _, phase in if phase == .background { voice.stop() } }.onDisappear { voice.cancel() }.errorAlert($error)
        }
    }
}
