import XCTest
@testable import LeaveWellCore

final class CoreTests: XCTestCase {
    func testImportsNeverInventCaptureTime() throws {
        let file = OriginalFile(relativePath: "originals/a.pdf", originalName: "inventory.pdf", sha256: "abc",
                                byteCount: 12, importedAt: Date(timeIntervalSince1970: 100), origin: .imported)
        var item = Evidence(kind: .document, label: "Inventory", original: file)
        item.notes = "Reviewed"; item.updatedAt = Date(timeIntervalSince1970: 200)
        XCTAssertNil(item.original?.capturedAt)
        XCTAssertEqual(item.original?.importedAt, file.importedAt)
        XCTAssertEqual(item.original?.sha256, "abc")
    }
    func testReadingRequiresExplicitConfirmation() {
        XCTAssertFalse(MeterReading(type: "Electricity", reading: "4862", confirmedByUser: false).isValid)
        XCTAssertFalse(MeterReading(type: "Gas", reading: "  ", confirmedByUser: true).isValid)
        XCTAssertTrue(MeterReading(type: "Electricity", reading: "004862.7", confirmedByUser: true).isValid)
    }
    func testReadinessCannotExceedOneFromStaleIDs() {
        var record = MoveCase(); record.completedTasks = Set(MovePlan.tasks(moveDate: record.moveDate).map(\.id))
        record.completedTasks.insert("unknown")
        XCTAssertEqual(record.readiness, 1)
        var room = Room(name: "Kitchen", category: "Kitchen"); room.reviewedItems = Set(room.items)
        room.reviewedItems.insert("removed fixture")
        XCTAssertEqual(room.progress, 1)
    }
    func testPlanUsesCalendarDaysAcrossDST() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 15))!
        let tasks = MovePlan.tasks(moveDate: date, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: tasks.first!.dueAt), 5)
        XCTAssertEqual(calendar.component(.hour, from: tasks.first!.dueAt), 0)
        XCTAssertEqual(tasks.count, 20)
        XCTAssertEqual(Set(tasks.map(\.id)).count, tasks.count)
    }
    func testSearchCombinesRoomTranscriptAndLabel() {
        var record = MoveCase(); let room = Room(name: "Bedroom", category: "Bedroom"); record.rooms = [room]
        record.evidence = [Evidence(roomID: room.id, kind: .photo, label: "Window", transcript: "Small scratch")]
        XCTAssertEqual(record.search("bedroom scratch").count, 1)
        XCTAssertEqual(record.search("oven").count, 0)
        XCTAssertEqual(record.search("  ").count, 1)
    }
    func testArchiveRoundTripPreservesEvidenceAndUnknownVersionFails() throws {
        var archive = Archive(); var record = MoveCase(now: Date(timeIntervalSince1970: 100))
        record.rooms = [Room(name: "Kitchen", category: "Kitchen")]
        record.evidence = [Evidence(kind: .note, label: "Cleaning", now: Date(timeIntervalSince1970: 120))]
        archive.cases = [record]
        let decoded = try ArchiveCodec.decode(ArchiveCodec.encode(archive))
        XCTAssertEqual(decoded.cases.first?.evidence.first?.id, record.evidence.first?.id)
        XCTAssertEqual(decoded.cases.first?.createdAt, record.createdAt)
        archive.schemaVersion = 99
        XCTAssertThrowsError(try ArchiveCodec.decode(ArchiveCodec.encode(archive)))
    }
    func testFractionalOriginalTimestampsSurvivePersistence() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000.123456)
        let file = OriginalFile(relativePath: "originals/test.jpg", originalName: "test.jpg", sha256: "hash",
                                byteCount: 3, capturedAt: date, createdAt: date, origin: .camera)
        var archive = Archive(); var record = MoveCase(now: date)
        record.evidence = [Evidence(kind: .photo, label: "Wall", original: file, now: date)]; archive.cases = [record]
        let decoded = try ArchiveCodec.decode(ArchiveCodec.encode(archive))
        XCTAssertEqual(decoded.cases.first?.evidence.first?.original?.capturedAt, date)
        XCTAssertEqual(decoded.cases.first?.evidence.first?.original?.createdAt, date)
    }
}
