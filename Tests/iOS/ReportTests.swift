import XCTest
import PDFKit
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import LeaveWell

@MainActor
final class ReportTests: XCTestCase {
    func testImportedGIFIsEmbeddedAsAnImage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try EvidenceVault(root: root)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let bytes = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(bytes, UTType.gif.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let original = try await vault.store(bytes as Data, name: "imported.gif", origin: .imported, capturedAt: nil)
        var record = MoveCase(); record.evidence = [Evidence(kind: .photo, label: "Imported GIF photograph", original: original)]
        let url = try await ReportService().generate(record: record, options: ReportOptions(), vault: vault)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let document = try XCTUnwrap(PDFDocument(url: url))
        var foundImage = false
        for index in 0..<document.pageCount {
            if let page = document.page(at: index)?.pageRef {
                var resources: CGPDFDictionaryRef?; var objects: CGPDFDictionaryRef?
                if CGPDFDictionaryGetDictionary(page.dictionary, "Resources", &resources), let resources,
                   CGPDFDictionaryGetDictionary(resources, "XObject", &objects), let objects,
                   CGPDFDictionaryGetCount(objects) > 0 { foundImage = true }
            }
        }
        XCTAssertTrue(foundImage, "Imported image formats must render in the PDF, not appear only as metadata")
    }
    func testContactAndDepositAreExcludedByDefaultAndIncludedOnlyWhenSelected() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try EvidenceVault(root: root)
        var record = MoveCase()
        record.agentName = "Private agent name"; record.agentContact = "private-agent@example.invalid"
        record.depositAmount = "1234.56"; record.depositScheme = "Private deposit scheme"
        let privateURL = try await ReportService().generate(record: record, options: ReportOptions(), vault: vault)
        let sharedURL = try await ReportService().generate(record: record, options: ReportOptions(includeContactDetails: true, includeDepositDetails: true), vault: vault)
        defer {
            try? FileManager.default.removeItem(at: privateURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: sharedURL.deletingLastPathComponent())
        }
        let privateText = try XCTUnwrap(PDFDocument(url: privateURL)?.string)
        let sharedText = try XCTUnwrap(PDFDocument(url: sharedURL)?.string)
        for value in [record.agentName, record.agentContact, record.depositAmount, record.depositScheme] {
            XCTAssertFalse(privateText.contains(value)); XCTAssertTrue(sharedText.contains(value))
        }
    }
    func testUnreadableIncludedImageOrPDFStopsReportInsteadOfSilentlyOmittingIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try EvidenceVault(root: root)
        for name in ["invalid.jpg", "invalid.pdf"] {
            let original = try await vault.store(Data("Unreadable media".utf8), name: name, origin: .imported, capturedAt: nil)
            var record = MoveCase(); record.evidence = [Evidence(kind: .document, label: name, original: original)]
            do { _ = try await ReportService().generate(record: record, options: ReportOptions(), vault: vault); XCTFail("Unreadable included originals must stop the report") }
            catch { XCTAssertTrue(error is ReportError) }
        }
    }
    func testReportExcludesUnselectedEvidenceAndPaginatesLongNotes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); try? ExportWorkspace.clear() }
        let vault = try EvidenceVault(root: root)
        var record = MoveCase(); record.nickname = "Test property"; record.address = "Sample address"; record.tenant = "Test renter"
        let room = Room(name: "Kitchen", category: "Kitchen"); record.rooms = [room]
        let visible = Evidence(roomID: room.id, kind: .note, label: "Oven condition record", notes: String(repeating: "Long factual note. ", count: 900) + "\nFinal observation retained.")
        var hidden = Evidence(roomID: room.id, kind: .note, label: "Excluded private record", notes: "Private excluded observation.")
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
        XCTAssertTrue(text.contains(visible.label), "Selected evidence title is absent from extracted PDF text: \(text.prefix(4000))")
        XCTAssertTrue(text.contains(visible.reference))
        XCTAssertTrue(text.contains("Final observation retained."), "Long notes must not be clipped at the final page.")
        XCTAssertFalse(text.contains(hidden.label)); XCTAssertFalse(text.contains(hidden.notes)); XCTAssertFalse(text.contains(hidden.reference))
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
