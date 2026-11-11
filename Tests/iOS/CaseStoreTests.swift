import XCTest
import UIKit
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
    func testInventoryUsesPageTextAndDeduplicatesImportsWithinACase() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try CaseStore(root: root)
        await store.load()
        let sampleID = try await store.practiceInventory()
        let source = try XCTUnwrap(store.record(sampleID)?.evidence.first?.original)
        let url = try await store.vault.verifiedURL(for: source)
        let reader = InventoryReader()
        let count = try await reader.pageCount(url)
        XCTAssertEqual(count, 1)
        let page = try await reader.read(url, page: 1, suggest: true)
        XCTAssertFalse(page.preview.isEmpty)
        XCTAssertTrue(page.suggestions.contains { $0.contains("light scratches beside the drain") })

        let record = MoveCase()
        try store.add(record)
        let first = try await store.importInventory(url, caseID: record.id, reader: reader)
        let second = try await store.importInventory(url, caseID: record.id, reader: reader)
        XCTAssertEqual(first, second)
        XCTAssertEqual(store.record(record.id)?.evidence.count, 1)
        XCTAssertNotEqual(first, store.record(sampleID)?.evidence.first?.id)
        XCTAssertEqual(store.record(sampleID)?.isPracticeRecord, true)
    }

    func testInventoryReadsAnImageOnlyPDF() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let image = UIGraphicsImageRenderer(size: bounds.size).image { renderer in
            UIColor.white.setFill()
            renderer.fill(bounds)
            ("Kitchen sink" as NSString).draw(at: CGPoint(x: 50, y: 80),
                                              withAttributes: [.font: UIFont.systemFont(ofSize: 42)])
        }
        let pdf = UIGraphicsPDFRenderer(bounds: bounds).pdfData { renderer in
            renderer.beginPage()
            image.draw(in: bounds)
        }
        let url = directory.appendingPathComponent("scan.pdf")
        try pdf.write(to: url)
        let page = try await InventoryReader().read(url, page: 1, suggest: true)
        XCTAssertTrue(page.suggestions.contains { $0.localizedCaseInsensitiveContains("Kitchen sink") })
    }
}
