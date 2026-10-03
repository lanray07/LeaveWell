import Foundation
import Observation

@MainActor @Observable
final class CaseStore {
    private(set) var archive = Archive()
    private(set) var ready = false
    var errorMessage: String?
    let vault: EvidenceVault
    private let indexURL: URL
    init() throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = support.appendingPathComponent("LeaveWell", isDirectory: true)
        vault = try EvidenceVault(root: root); indexURL = root.appendingPathComponent("records.json")
    }
    func load() async {
        do {
            if FileManager.default.fileExists(atPath: indexURL.path) { archive = try ArchiveCodec.decode(Data(contentsOf: indexURL)) }
            let paths = Set(archive.cases.flatMap(\.evidence).flatMap { item in
                ([item.original].compactMap { $0 } + item.derivatives).map(\.relativePath)
            })
            try await vault.reconcile(referenced: paths)
            ready = true
        } catch { errorMessage = L("Your records could not be opened. No records have been overwritten.") + "\n" + error.localizedDescription }
    }
    func record(_ id: UUID) -> MoveCase? { archive.cases.first { $0.id == id } }
    private func commit(_ next: Archive) throws {
        try ArchiveCodec.encode(next).write(to: indexURL, options: [.atomic, .completeFileProtection])
        archive = next
    }
    func add(_ record: MoveCase) throws {
        var next = archive; next.cases.append(record); try commit(next)
    }
    func update(_ id: UUID, action: String? = nil, detail: String = "", mutation: (inout MoveCase) -> Void) throws {
        var next = archive
        guard let index = next.cases.firstIndex(where: { $0.id == id }) else { throw VaultError.missingFile }
        mutation(&next.cases[index]); next.cases[index].updatedAt = Date()
        if let action {
            next.cases[index].activities.append(Activity(action: action, detail: detail, contributor: next.cases[index].tenant))
        }
        try commit(next)
    }
    func addEvidence(_ item: Evidence, caseID: UUID) async throws {
        do { try update(caseID, action: "Evidence added", detail: item.label) { $0.evidence.append(item) } }
        catch { if let original = item.original { try? await vault.remove(original) }; throw error }
    }
    func deleteEvidence(_ evidence: Evidence, caseID: UUID) async throws {
        try update(caseID, action: "Evidence deleted", detail: evidence.reference) { record in
            record.evidence.removeAll { $0.id == evidence.id }
            for index in record.meters.indices where record.meters[index].evidenceID == evidence.id { record.meters[index].evidenceID = nil }
            for index in record.accessItems.indices where record.accessItems[index].evidenceID == evidence.id { record.accessItems[index].evidenceID = nil }
        }
        for original in [evidence.original].compactMap({ $0 }) + evidence.derivatives { try await vault.remove(original) }
    }
    func deleteCase(_ id: UUID) async throws {
        let originals = record(id)?.evidence.flatMap { [$0.original].compactMap { $0 } + $0.derivatives } ?? []
        var next = archive; next.cases.removeAll { $0.id == id }; try commit(next)
        for original in originals { try await vault.remove(original) }
        await ReminderService.cancel(caseID: id)
    }
    func exportData() async throws -> [URL] {
        let directory = try ExportWorkspace.make()
        let manifest = directory.appendingPathComponent("records.json")
        try ArchiveCodec.encode(archive).write(to: manifest, options: [.atomic, .completeFileProtection])
        var urls = [manifest]
        for item in archive.cases.flatMap(\.evidence) {
            for original in [item.original].compactMap({ $0 }) + item.derivatives {
                let source = try await vault.verifiedURL(for: original)
                let target = directory.appendingPathComponent(source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: target)
                try EvidenceVault.protect(target); urls.append(target)
            }
        }
        return urls
    }
}

enum ExportWorkspace {
    static var root: URL { FileManager.default.temporaryDirectory.appendingPathComponent("LeaveWellExports", isDirectory: true) }
    static func make() throws -> URL {
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try EvidenceVault.protect(directory)
        return directory
    }
    static func clear() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }
}
