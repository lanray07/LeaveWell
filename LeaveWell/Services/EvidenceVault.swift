import Foundation
import CryptoKit

enum VaultError: LocalizedError {
    case invalidPath, missingFile, integrityMismatch, emptyFile
    var errorDescription: String? {
        switch self {
        case .invalidPath: L("The evidence path could not be opened safely.")
        case .missingFile: L("An original evidence file is missing. The record has been kept.")
        case .integrityMismatch: L("An original file failed its integrity check. Export was stopped.")
        case .emptyFile: L("The selected file is empty.")
        }
    }
}

protocol EvidenceStorage: Sendable {
    func importFile(at url: URL, origin: CaptureOrigin, capturedAt: Date?) async throws -> OriginalFile
    func store(_ data: Data, name: String, origin: CaptureOrigin, capturedAt: Date?) async throws -> OriginalFile
    func verifiedURL(for original: OriginalFile) async throws -> URL
    func remove(_ original: OriginalFile) async throws
}

actor EvidenceVault: EvidenceStorage {
    let root: URL
    init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root.appendingPathComponent("originals"), withIntermediateDirectories: true)
        try Self.protect(root)
    }
    static func protect(_ url: URL) throws {
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var mutable = url; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }
    private func destination(name: String) -> (String, URL) {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
            .filter { $0.isLetter || $0.isNumber }
        let path = "originals/" + UUID().uuidString + (ext.isEmpty ? "" : "." + String(ext.prefix(10)))
        return (path, root.appendingPathComponent(path))
    }
    func importFile(at url: URL, origin: CaptureOrigin, capturedAt: Date?) async throws -> OriginalFile {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let (path, target) = destination(name: url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: target)
            try Self.protect(target)
            return try metadata(at: target, path: path, name: url.lastPathComponent, origin: origin, capturedAt: capturedAt)
        } catch { try? FileManager.default.removeItem(at: target); throw error }
    }
    func store(_ data: Data, name: String, origin: CaptureOrigin, capturedAt: Date?) async throws -> OriginalFile {
        guard !data.isEmpty else { throw VaultError.emptyFile }
        let (path, target) = destination(name: name)
        do {
            try data.write(to: target, options: [.atomic, .completeFileProtection])
            try Self.protect(target)
            return try metadata(at: target, path: path, name: name, origin: origin, capturedAt: capturedAt)
        } catch { try? FileManager.default.removeItem(at: target); throw error }
    }
    private func metadata(at url: URL, path: String, name: String, origin: CaptureOrigin, capturedAt: Date?) throws -> OriginalFile {
        let (hash, count) = try Self.digest(url)
        guard count > 0 else { throw VaultError.emptyFile }
        let now = Date()
        return OriginalFile(relativePath: path, originalName: name, sha256: hash, byteCount: count,
                            capturedAt: capturedAt, importedAt: origin == .imported ? now : nil, createdAt: now, origin: origin)
    }
    static func digest(_ url: URL) throws -> (String, Int) {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hasher = SHA256(); var count = 0
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty { hasher.update(data: chunk); count += chunk.count }
        return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), count)
    }
    private func safeURL(_ path: String) throws -> URL {
        guard path.hasPrefix("originals/"), !path.contains(".."), !path.contains("\\"),
              path.split(separator: "/").count == 2 else { throw VaultError.invalidPath }
        return root.appendingPathComponent(path)
    }
    func verifiedURL(for original: OriginalFile) async throws -> URL {
        let url = try safeURL(original.relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { throw VaultError.missingFile }
        let (hash, count) = try Self.digest(url)
        guard hash == original.sha256, count == original.byteCount else { throw VaultError.integrityMismatch }
        return url
    }
    func remove(_ original: OriginalFile) async throws {
        let url = try safeURL(original.relativePath)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    /// Reconcile only during startup, before new imports can begin.
    func reconcile(referenced: Set<String>) throws {
        for url in try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("originals"), includingPropertiesForKeys: nil) {
            if !referenced.contains("originals/" + url.lastPathComponent) { try FileManager.default.removeItem(at: url) }
        }
    }
}
