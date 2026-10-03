import XCTest
@testable import LeaveWell

@MainActor
final class CaseStoreTests: XCTestCase {
    func testPersistenceExportAndEvidenceDeletionPreserveAssociations() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try CaseStore(root: root)
        await store.load()
        let bytes = Data("Original rental evidence".utf8)
        let file = try await store.vault.store(bytes, name: "receipt.txt", origin: .imported, capturedAt: nil)
        let evidence = Evidence(kind: .document, label: "Receipt", original: file)
        var record = MoveCase(); record.evidence = [evidence]
        record.meters = [MeterReading(type: "Electricity", reading: "00123", evidenceID: evidence.id, confirmedByUser: true)]
        record.accessItems = [AccessItem(type: "Front door key", evidenceID: evidence.id)]
        try store.add(record)
        let reloaded = try CaseStore(root: root); await reloaded.load()
        XCTAssertTrue(reloaded.ready)
        XCTAssertEqual(reloaded.record(record.id)?.evidence.first?.original?.sha256, file.sha256)
        let urls = try await reloaded.exportData()
        defer { if let directory = urls.first?.deletingLastPathComponent() { try? FileManager.default.removeItem(at: directory) } }
        XCTAssertEqual(urls.count, 2)
        let exported = try ArchiveCodec.decode(Data(contentsOf: urls[0]))
        XCTAssertEqual(exported.cases.first?.id, record.id)
        XCTAssertEqual(try Data(contentsOf: urls[1]), bytes)
        try await reloaded.deleteEvidence(evidence, caseID: record.id)
        XCTAssertTrue(try XCTUnwrap(reloaded.record(record.id)).evidence.isEmpty)
        XCTAssertNil(reloaded.record(record.id)?.meters.first?.evidenceID)
        XCTAssertNil(reloaded.record(record.id)?.accessItems.first?.evidenceID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(file.relativePath).path))
    }
    func testCorruptManifestDoesNotDeleteOriginalsOrOverwriteRecords() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try CaseStore(root: root)
        let file = try await store.vault.store(Data([1, 2, 3]), name: "original.bin", origin: .imported, capturedAt: nil)
        let corrupt = Data("invalid archive".utf8)
        let manifest = root.appendingPathComponent("records.json")
        try corrupt.write(to: manifest)
        await store.load()
        XCTAssertFalse(store.ready); XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: manifest), corrupt)
        _ = try await store.vault.verifiedURL(for: file)
    }
}
