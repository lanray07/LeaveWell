import SwiftUI

struct MetersView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var adding = false
    @State private var selection: CaptureSelection?
    var body: some View {
        List {
            Section { Text(L("Keep the displayed digits, including leading zeroes. Add a photograph and confirm the reading yourself.")).foregroundStyle(.secondary) }
            ForEach(store.record(caseID)?.meters ?? []) { meter in
                VStack(alignment: .leading, spacing: 8) {
                    Text(L(meter.type)).font(.headline)
                    Text(meter.reading).font(.title.monospacedDigit()).foregroundStyle(Theme.accent)
                    Text(meter.recordedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    if !meter.serialNumber.isEmpty { Text(L("Serial number") + ": " + meter.serialNumber).font(.caption) }
                    if !meter.notes.isEmpty { Text(meter.notes) }
                    if let id = meter.evidenceID { NavigationLink(L("View meter evidence")) { EvidenceDetailView(caseID: caseID, evidenceID: id) } }
                }.padding(.vertical, 8)
            }
            Button(L("Add meter photograph")) { selection = CaptureSelection(label: "Meter", kind: .photo) }
        }.navigationTitle(L("Meter readings"))
            .toolbar { Button(L("Add reading")) { adding = true } }
            .sheet(isPresented: $adding) { MeterEditor(caseID: caseID) }
            .sheet(item: $selection) { EvidenceComposer(caseID: caseID, selection: $0) }
    }
}

struct MeterEditor: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let caseID: UUID
    @State private var type = "Electricity"
    @State private var customType = ""
    @State private var reading = ""
    @State private var serial = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var evidenceID: UUID?
    @State private var confirmed = false
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var voice = VoiceService()
    @State private var suggestions: [String] = []
    @State private var recognizing = false
    var body: some View {
        NavigationStack {
            Form {
                Section(L("Meter details")) {
                    Picker(L("Meter type"), selection: $type) { ForEach(["Electricity", "Gas", "Water", "Heating", "Prepayment", "Custom"], id: \.self) { Text(L($0)).tag($0) } }
                    if type == "Custom" { TextField(L("Custom meter type"), text: $customType) }
                    TextField(L("Reading"), text: $reading).keyboardType(.decimalPad).onChange(of: reading) { _, _ in confirmed = false }
                    TextField(L("Serial number"), text: $serial)
                    DatePicker(L("Recorded at"), selection: $date)
                    TextField(L("Notes"), text: $notes, axis: .vertical)
                    Picker(L("Meter photograph"), selection: $evidenceID) {
                        Text(L("No photograph selected")).tag(UUID?.none)
                        ForEach(store.record(caseID)?.evidence.filter { $0.kind == .photo } ?? []) { Text($0.label).tag(Optional($0.id)) }
                    }
                    if let id = evidenceID {
                        Button(L("Suggest reading from photograph")) {
                            Task {
                                recognizing = true; defer { recognizing = false }
                                do {
                                    if let original = store.record(caseID)?.evidence.first(where: { $0.id == id })?.original {
                                        let url = try await store.vault.verifiedURL(for: original)
                                        suggestions = try await MeterOCR().candidates(from: url)
                                        if suggestions.isEmpty { self.error = L("No reading was found. Enter the digits shown on the meter.") }
                                    }
                                } catch { self.error = error.localizedDescription }
                            }
                        }.disabled(recognizing)
                    }
                    if recognizing { ProgressView(L("Reading photograph on device…")) }
                    if !suggestions.isEmpty {
                        Text(L("Suggested digits may include a serial number. Select a draft, then check it against the meter.")).font(.footnote)
                        ForEach(suggestions, id: \.self) { candidate in Button(candidate) { reading = candidate; confirmed = false } }
                    }
                }
                Section(L("Voice meter note")) {
                    Button(voice.recording ? L("Stop and transcribe") : L("Record a voice note")) {
                        Task { if voice.recording { await voice.stopAndTranscribe(); notes = voice.transcript } else { await voice.start() } }
                    }.disabled(voice.starting || voice.processing)
                    if !voice.transcript.isEmpty { Text(voice.transcript); Text(L("Enter the digits above, then confirm them against the meter.")).font(.footnote) }
                    if let message = voice.error { Text(message).font(.footnote) }
                }
                Section {
                    Text(L("Please confirm the reading matches the meter.")).font(.headline)
                    Toggle(L("I have checked the reading"), isOn: $confirmed)
                }
            }.navigationTitle(L("Add meter reading"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L("Save")) {
                        do {
                            let meter = MeterReading(type: type == "Custom" ? customType : type, reading: reading, serialNumber: serial, notes: notes, recordedAt: date, evidenceID: evidenceID, confirmedByUser: confirmed)
                            guard meter.isValid else { return }
                            try store.update(caseID, action: "Meter reading recorded", detail: L(meter.type)) { $0.meters.append(meter) }; dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(!confirmed || reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (type == "Custom" && customType.isEmpty) || voice.starting || voice.recording || voice.processing) }
                }.onChange(of: scenePhase) { _, phase in if phase == .background { voice.stop() } }.onDisappear { voice.cancel() }.errorAlert($error)
        }
    }
}
