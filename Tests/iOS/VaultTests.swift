import XCTest
@testable import LeaveWell

final class VaultTests: XCTestCase {
    func testOriginalIsHashedAndTamperingStopsExport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try EvidenceVault(root: root)
        let file = try await vault.store(Data("original evidence".utf8), name: "note.txt", origin: .imported, capturedAt: nil)
        XCTAssertEqual(file.sha256, "37a084be87246ef17563f0337770335bf02cd3d9cccb623b02e6b70d973ef74b")
        let url = try await vault.verifiedURL(for: file)
        try Data("changed evidence".utf8).write(to: url)
        do { _ = try await vault.verifiedURL(for: file); XCTFail("Modified evidence must never pass verification") }
        catch { XCTAssertTrue(error is VaultError) }
    }
    func testImportedTimeDoesNotBecomeCaptureTime() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try EvidenceVault(root: root)
        let original = try await vault.store(Data([1, 2, 3]), name: "photo.jpg", origin: .imported, capturedAt: nil)
        XCTAssertNotNil(original.importedAt); XCTAssertNil(original.capturedAt)
    }
    func testPathTraversalRejected() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try EvidenceVault(root: root)
        let invalid = OriginalFile(relativePath: "originals/../../private.txt", originalName: "private.txt", sha256: "", byteCount: 1, origin: .imported)
        do { _ = try await vault.verifiedURL(for: invalid); XCTFail("Traversal must fail") }
        catch { XCTAssertTrue(error is VaultError) }
    }
}
