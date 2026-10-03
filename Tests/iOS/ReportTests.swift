import XCTest
import PDFKit
import UIKit
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
        let samples = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TestReports")
        try FileManager.default.createDirectory(at: samples, withIntermediateDirectories: true)
        try Data(contentsOf: url).write(to: samples.appendingPathComponent("LeaveWell-sample.pdf"))
        try text.write(to: samples.appendingPathComponent("extracted-text.txt"), atomically: true, encoding: .utf8)
        for index in 0..<min(document.pageCount, 4) {
            if let page = document.page(at: index) {
                let image = UIGraphicsImageRenderer(size: CGSize(width: 595, height: 842)).image { context in
                    UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
                    context.cgContext.translateBy(x: 0, y: 842); context.cgContext.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: context.cgContext)
                }
                try image.pngData()?.write(to: samples.appendingPathComponent("page-\(index + 1).png"))
            }
        }
        XCTAssertGreaterThan(document.pageCount, 8)
        XCTAssertTrue(text.contains("VISIBLE_RECORD"), "Selected evidence title is absent from extracted PDF text: \(text.prefix(4000))")
        XCTAssertFalse(text.contains("EXCLUDED_SECRET_RECORD")); XCTAssertFalse(text.contains("SECRET_PRIVATE_NOTE"))
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
