import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import VisionKit

struct EvidenceComposer: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let caseID: UUID
    let selection: CaptureSelection
    @State private var label: String
    @State private var notes = ""
    @State private var condition = Condition.noIssue
    @State private var originals: [OriginalFile] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showImporter = false
    @State private var capture: CaptureModal?
    @State private var kind: EvidenceKind
    @State private var busy = false
    @State private var saved = false
    @State private var error: String?
    @State private var voice = VoiceService()
    @State private var importedVoiceURL: URL?
    init(caseID: UUID, selection: CaptureSelection) {
        self.caseID = caseID; self.selection = selection
        _label = State(initialValue: L(selection.label)); _kind = State(initialValue: selection.kind)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(L("What does this record show?")) {
                    TextField(L("Label or category"), text: $label)
                    Picker(L("Record type"), selection: $kind) { ForEach(EvidenceKind.allCases, id: \.self) { Text($0.title).tag($0) } }.disabled(!originals.isEmpty)
                    Picker(L("Condition"), selection: $condition) { ForEach(Condition.allCases, id: \.self) { Text($0.title).tag($0) } }
                }
                if kind != .note && kind != .audio {
                    Section(L("Original files")) {
                        if kind == .photo || kind == .video {
                            Button(kind == .video ? L("Record room walkthrough") : L("Take a photograph")) { Task { await openCamera() } }
                            PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: kind == .video ? .videos : .images, preferredItemEncoding: .current) { Label(L("Choose from library"), systemImage: "photo.on.rectangle") }
                            if kind == .video { Text(L("Move slowly and capture the entire room. Narration is included when microphone access is allowed.")).font(.footnote).foregroundStyle(.secondary) }
                        }
                        Button(L("Import files")) { showImporter = true }
                        if kind == .document && VNDocumentCameraViewController.isSupported { Button(L("Scan document")) { capture = .scanner } }
                        ForEach(originals) { original in
                            VStack(alignment: .leading, spacing: 4) { Text(original.originalName); Text(L("Saved on device") + " · " + ByteCountFormatter.string(fromByteCount: Int64(original.byteCount), countStyle: .file)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section(L("Notes")) {
                    TextField(L("Describe what you documented"), text: $notes, axis: .vertical).lineLimit(4...12)
                    Button {
                        Task {
                            if voice.recording { await voice.stopAndTranscribe(); if !voice.transcript.isEmpty { notes = [notes, voice.transcript].filter { !$0.isEmpty }.joined(separator: "\n") } }
                            else { await voice.start() }
                        }
                    } label: { Label(voice.recording ? L("Stop and transcribe") : L("Record a voice note"), systemImage: voice.recording ? "stop.circle.fill" : "mic") }
                    .disabled(voice.processing)
                    if voice.processing { ProgressView(L("Transcribing on device…")) }
                    if voice.recording { Text(L("Recording… Tap stop when you have finished.")).foregroundStyle(Theme.accent) }
                    if let voiceError = voice.error { Text(voiceError).font(.footnote).foregroundStyle(.secondary) }
                    if voice.recordingURL != nil && !voice.recording { Text(L("Review and edit the text before saving. Your voice recording will also be preserved.")).font(.footnote).foregroundStyle(.secondary) }
                }
                Section { Text(L("Original files are preserved. Imported files are labelled with import time; an unknown capture time is left unknown.")).font(.footnote).foregroundStyle(.secondary) }
                if busy { Section { ProgressView(L("Saving your evidence…")) } }
            }.disabled(busy)
                .navigationTitle(L("Add evidence"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button(L("Save")) { Task { await save() } }.disabled(!canSave || busy) }
                }
                .fileImporter(isPresented: $showImporter, allowedContentTypes: allowedTypes, allowsMultipleSelection: true) { result in
                    Task { do { for url in try result.get() { try await importURL(url, origin: .imported, captured: nil) } } catch { self.error = error.localizedDescription } }
                }
                .fullScreenCover(item: $capture) { modal in
                    switch modal {
                    case .camera:
                        SystemCamera(video: kind == .video) { result in
                            if let result {
                                Task {
                                    busy = true; defer { busy = false }
                                    do {
                                        let media = try result.get()
                                        if let url = media.url { try await importURL(url, origin: media.origin, captured: media.capturedAt) }
                                        else if let data = media.data { let file = try await store.vault.store(data, name: media.name, origin: media.origin, capturedAt: media.capturedAt); originals.append(file) }
                                    } catch { self.error = error.localizedDescription }
                                    capture = nil
                                }
                            } else { capture = nil }
                        }.ignoresSafeArea()
                    case .scanner:
                        DocumentScanner { result in
                            Task {
                                do {
                                    if let result { for (index, page) in try result.get().enumerated() { let file = try await store.vault.store(page, name: "scan-\(index + 1).jpg", origin: .scanned, capturedAt: Date()); originals.append(file) } }
                                } catch { self.error = error.localizedDescription }
                                capture = nil
                            }
                        }.ignoresSafeArea()
                    }
                }
                .onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
                .onChange(of: scenePhase) { _, phase in if phase == .background { voice.stop() } }
                .onDisappear {
                    guard capture == nil else { return }
                    voice.cancel()
                    if !saved { let discarded = originals; Task { for file in discarded { try? await store.vault.remove(file) } } }
                }.interactiveDismissDisabled(busy).errorAlert($error)
        }
    }
    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !voice.recording && !voice.processing &&
        (kind == .note ? !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : (kind == .audio ? voice.recordingURL != nil : !originals.isEmpty))
    }
    private var allowedTypes: [UTType] {
        switch kind { case .photo: [.image]; case .video: [.movie]; case .document: [.pdf, .image]; default: [.audio] }
    }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = L("The camera is unavailable. Choose a file from your library instead."); return }
        guard await AVCaptureDevice.requestAccess(for: .video) else { error = L("Camera access is disabled. You can import evidence instead."); return }
        if kind == .video { _ = await AVAudioApplication.requestRecordPermission() }
        capture = .camera
    }
    private func importURL(_ url: URL, origin: CaptureOrigin, captured: Date?) async throws {
        busy = true; defer { busy = false }
        let file = try await store.vault.importFile(at: url, origin: origin, capturedAt: captured); originals.append(file)
    }
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        busy = true; defer { busy = false; photoItems = [] }
        do {
            for item in items {
                guard let imported = try await item.loadTransferable(type: ImportedMedia.self) else { throw VaultError.emptyFile }
                let file = try await store.vault.importFile(at: imported.url, origin: .imported, capturedAt: nil)
                originals.append(file); try? FileManager.default.removeItem(at: imported.url)
            }
        } catch { self.error = error.localizedDescription }
    }
    private func save() async {
        guard canSave else { return }
        busy = true; defer { busy = false }
        do {
            if let url = voice.recordingURL, importedVoiceURL != url {
                let original = try await store.vault.importFile(at: url, origin: .recorded, capturedAt: voice.startedAt)
                originals.append(original)
                importedVoiceURL = url
            }
            let tenant = store.record(caseID)?.tenant ?? ""
            let items: [Evidence]
            if originals.isEmpty { items = [Evidence(roomID: selection.roomID, kind: .note, label: label, notes: notes, condition: condition, contributor: tenant)] }
            else {
                items = originals.map { original in
                    let actualKind: EvidenceKind = original.origin == .recorded ? .audio : kind
                    return Evidence(roomID: selection.roomID, kind: actualKind, label: label, notes: notes, transcript: voice.transcript, condition: condition, original: original, contributor: tenant)
                }
            }
            try store.update(caseID, action: "Evidence added", detail: label) { $0.evidence.append(contentsOf: items) }
            saved = true; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private enum CaptureModal: String, Identifiable { case camera, scanner; var id: String { rawValue } }
private struct ImportedMedia: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .data) { received in
            let directory = try ExportWorkspace.make()
            let target = directory.appendingPathComponent(received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: target); try EvidenceVault.protect(target)
            return ImportedMedia(url: target)
        }
    }
}
