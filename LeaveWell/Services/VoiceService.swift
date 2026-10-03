import Foundation
import AVFoundation
import Speech
import Observation

@MainActor @Observable
final class VoiceService {
    var recording = false
    var processing = false
    var transcript = ""
    var error: String?
    private var recorder: AVAudioRecorder?
    private var recognition: SFSpeechRecognitionTask?
    private(set) var recordingURL: URL?
    private(set) var startedAt: Date?
    func start() async {
        do {
            guard await AVAudioApplication.requestRecordPermission() else { throw VoiceError.microphoneDenied }
            let directory = try ExportWorkspace.make()
            let url = directory.appendingPathComponent("voice.m4a")
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default); try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            guard recorder.record() else { throw VoiceError.recordingFailed }
            self.recorder = recorder; recordingURL = url; startedAt = Date(); recording = true; transcript = ""; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func stopAndTranscribe() async {
        guard recording else { return }
        stop(); processing = true; defer { processing = false }
        guard let url = recordingURL else { return }
        do {
            let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
            guard status == .authorized else { throw VoiceError.speechDenied }
            guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else { throw VoiceError.onDeviceUnavailable }
            let request = SFSpeechURLRecognitionRequest(url: url); request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false
            transcript = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                let gate = RecognitionGate(continuation)
                recognition = recognizer.recognitionTask(with: request) { result, failure in
                    if let result, result.isFinal { gate.finish(.success(result.bestTranscription.formattedString)) }
                    else if let failure { gate.finish(.failure(failure)) }
                }
                Task { try? await Task.sleep(for: .seconds(30)); if gate.finish(.failure(VoiceError.timeout)) { self.recognition?.cancel() } }
            }
        } catch { self.error = error.localizedDescription }
    }
    func stop() {
        recorder?.stop(); recorder = nil; recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func cancel() { stop(); recognition?.cancel() }
}

private final class RecognitionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    init(_ continuation: CheckedContinuation<String, Error>) { self.continuation = continuation }
    @discardableResult func finish(_ result: Result<String, Error>) -> Bool {
        lock.lock(); let value = continuation; continuation = nil; lock.unlock()
        value?.resume(with: result); return value != nil
    }
}
enum VoiceError: LocalizedError {
    case microphoneDenied, speechDenied, onDeviceUnavailable, recordingFailed, timeout
    var errorDescription: String? {
        switch self {
        case .microphoneDenied: L("Microphone access is disabled. You can type your note instead.")
        case .speechDenied: L("Speech recognition is disabled. Your recording is available and you can type a note.")
        case .onDeviceUnavailable: L("On-device transcription is unavailable for this language. Your audio stays on this device; type a note instead.")
        case .recordingFailed: L("Recording could not start. Please try again.")
        case .timeout: L("Transcription timed out. Your recording is still available.")
        }
    }
}
