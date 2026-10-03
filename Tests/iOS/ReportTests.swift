import XCTest
import PDFKit
@testable import LeaveWell

@MainActor
final class ReportTests: XCTestCase {
    func testReportExcludesUnselectedEvidenceAndPaginatesLongNotes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); try? ExportWorkspace.clear() }
        let vault = try EvidenceVault(root: root)
        var record = MoveCase(); record.nickname = "Test property"; record.address = "Sample address"; record.tenant = "Test renter"
        let room = Room(name: "Kitchen", category: "Kitchen"); record.rooms = [room]
        let visible = Evidence(roomID: room.id, kind: .note, label: "VISIBLE_RECORD", notes: String(repeating: "Long factual note. ", count: 900))
        var hidden = Evidence(roomID: room.id, kind: .note, label: "EXCLUDED_SECRET_RECORD", notes: "SECRET_PRIVATE_NOTE")
        hidden.includedInReport = false; record.evidence = [visible, hidden]
        let url = try await ReportService().generate(record: record, options: ReportOptions(), vault: vault)
        let document = try XCTUnwrap(PDFDocument(url: url)); let text = try XCTUnwrap(document.string)
        XCTAssertGreaterThan(document.pageCount, 8)
        XCTAssertTrue(text.contains("VISIBLE_RECORD")); XCTAssertFalse(text.contains("EXCLUDED_SECRET_RECORD")); XCTAssertFalse(text.contains("SECRET_PRIVATE_NOTE"))
        XCTAssertTrue(text.contains(record.reference))
    }
    func testReportStopsForMissingOriginal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try EvidenceVault(root: root)
        let file = try await vault.store(Data([1, 2, 3]), name: "test.jpg", origin: .camera, capturedAt: Date())
        var record = MoveCase(); record.evidence = [Evidence(kind: .photo, label: "Photo", original: file)]
        try await vault.remove(file)
        do { _ = try await ReportService().generate(record: record, options: ReportOptions(), vault: vault); XCTFail("Missing originals must block export") }
        catch { XCTAssertTrue(error is VaultError) }
    }
}
