import SwiftUI
import AVFoundation

/// Deterministic, case-grounded assistant. No evidence is sent to an AI provider.
struct AssistantView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var question = ""
    @State private var answer = ""
    @State private var matches: [Evidence] = []
    @State private var voice = VoiceService()
    @State private var speaker = AVSpeechSynthesizer()
    private let suggestions = ["Which rooms are incomplete?", "Have I recorded the electricity meter?", "Did I record my keys?", "Find my cleaning receipt."]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(L("A little help with your move.")).font(.largeTitle.bold())
                Text(L("Answers come from this record. The assistant can show missing room checks, meter records, keys and matching evidence.")).foregroundStyle(.secondary)
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(suggestions, id: \.self) { prompt in Button(L(prompt)) { question = L(prompt); respond(intent: prompt) }.frame(minHeight: 44, alignment: .leading) }
                    }
                }
                TextField(L("Search your case or ask what is missing"), text: $question, axis: .vertical).padding(16).background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                HStack {
                    Button(L("Ask LeaveWell")) { respond(intent: question) }.buttonStyle(.borderedProminent).disabled(question.isEmpty)
                    Button {
                        Task { if voice.recording { await voice.stopAndTranscribe(); question = voice.transcript } else { await voice.start() } }
                    } label: { Image(systemName: voice.recording ? "stop.circle" : "mic").frame(minWidth: 44, minHeight: 44).accessibilityLabel(voice.recording ? L("Stop and transcribe") : L("Speak your question")) }.disabled(voice.processing)
                }
                if let error = voice.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                if !answer.isEmpty {
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(answer).textSelection(.enabled)
                            Button(L("Read aloud")) {
                                speaker.stopSpeaking(at: .immediate)
                                let utterance = AVSpeechUtterance(string: answer); utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
                                speaker.speak(utterance)
                            }
                        }
                    }
                    ForEach(matches) { item in NavigationLink { EvidenceDetailView(caseID: caseID, evidenceID: item.id) } label: { EvidenceRow(item: item) }.buttonStyle(.plain) }
                }
                Text(L("LeaveWell organises evidence. It does not make legal decisions.")).font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }.background(Theme.background).navigationTitle(L("LeaveWell assistant"))
            .onDisappear { voice.cancel(); speaker.stopSpeaking(at: .immediate) }
    }
    private func respond(intent: String) {
        guard let record = store.record(caseID) else { answer = L("This record is unavailable."); return }
        matches = []
        let query = intent.lowercased()
        if intent == suggestions[0] || query.contains("incomplete") || query.contains("missing") || query.contains("haven't") {
            let roomMatch = record.rooms.first { query.contains($0.name.lowercased()) }
            let rooms = roomMatch.map { [$0] } ?? record.rooms
            let missing = rooms.filter { $0.progress < 1 }.map { room in room.name + ": " + room.items.filter { !room.reviewedItems.contains($0) }.map(L).joined(separator: ", ") }
            answer = missing.isEmpty ? L("All selected room checks have been reviewed. Review your evidence before preparing the report.") : L("Still to review:") + "\n\n" + missing.joined(separator: "\n\n")
            if rooms.isEmpty { answer = L("No rooms have been added to this record.") }
        } else if intent == suggestions[1] || query.contains("meter") {
            let meters = query.contains("electric") ? record.meters.filter { $0.type == "Electricity" } : record.meters
            answer = meters.isEmpty ? L("No matching meter reading is recorded yet.") : meters.map { L($0.type) + ": " + $0.reading + " · " + $0.recordedAt.formatted(date: .abbreviated, time: .shortened) }.joined(separator: "\n")
        } else if intent == suggestions[2] || query.contains("keys") || query.contains("fob") {
            answer = record.accessItems.isEmpty ? L("No access items are recorded yet.") : record.accessItems.map { "\($0.quantity) " + L($0.type) + " · " + ($0.handedOverAt == nil ? L("Handover not recorded") : L("Handed over")) }.joined(separator: "\n")
        } else {
            let search = intent == suggestions[3] ? "cleaning" : query
            matches = record.search(search)
            answer = matches.isEmpty ? L("I could not find matching evidence. Try a room, label, or words from your note.") : L("Matching records are shown below.")
        }
    }
}
