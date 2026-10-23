import XCTest
@testable import LeaveWellCore

final class CheckoutTests: XCTestCase {
    private func completeCase() -> MoveCase {
        var record = MoveCase()
        var room = Room(name: "Kitchen"); room.items = ["Window"]
        record.rooms = [room]; record.checkout = CheckoutSession()
        record.checkout?.fixtures = [FixtureReview(roomID: room.id, fixture: "Window", outcome: .checked, observation: "Latch closes", evidenceIDs: [])]
        record.checkout?.meters = [MeterRequirement(type: "Water", exclusionReason: "Included supply; no individual meter")]
        record.checkout?.accessInventoryChecked = true
        record.accessItems = [AccessItem(type: "Key", method: "In person", recipient: "Agent", handedOverAt: Date(timeIntervalSince1970: 100))]
        return record
    }
    func testLegacyArchiveWithoutCheckoutStillLoadsAndDoesNotInventReview() throws {
        var archive = Archive(); archive.cases = [MoveCase()]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: ArchiveCodec.encode(archive)) as? [String: Any])
        var cases = try XCTUnwrap(json["cases"] as? [[String: Any]])
        cases[0].removeValue(forKey: "checkout"); json["cases"] = cases
        let decoded = try ArchiveCodec.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.cases[0].checkout); XCTAssertFalse(decoded.cases[0].checkoutReviewIsCurrent)
        XCTAssertFalse(decoded.cases[0].checkoutGaps.isEmpty)
    }
    func testOldChecklistTicksDoNotCompleteDocumentedChecks() {
        var record = completeCase(); record.checkout?.fixtures = []
        record.rooms[0].reviewedItems = ["Window"]
        XCTAssertTrue(record.checkoutGaps.contains { $0.area == .rooms })
    }
    func testChangeRequiresNoteAndExistingEvidenceInTheSameRoom() {
        var record = completeCase(); let room = record.rooms[0]
        let photo = Evidence(roomID: room.id, kind: .photo, label: "Window")
        record.evidence = [photo]
        var review = FixtureReview(roomID: room.id, fixture: "Window", outcome: .change, observation: "Scratch", evidenceIDs: [])
        XCTAssertFalse(record.validFixtureReview(review))
        review.evidenceIDs = [photo.id]; XCTAssertTrue(record.validFixtureReview(review))
        record.evidence[0].roomID = UUID(); XCTAssertFalse(record.validFixtureReview(review))
        review.outcome = .notApplicable; review.observation = "  "; XCTAssertFalse(record.validFixtureReview(review))
    }
    func testCheckpointSurvivesPersistenceButContentEditsMakeItStale() throws {
        var record = completeCase(); XCTAssertTrue(record.checkoutGaps.isEmpty)
        try record.finishCheckoutReview(); XCTAssertTrue(record.checkoutReviewIsCurrent)
        var archive = Archive(); archive.cases = [record]
        var decoded = try ArchiveCodec.decode(ArchiveCodec.encode(archive)).cases[0]
        XCTAssertTrue(decoded.checkoutReviewIsCurrent)
        decoded.activities.append(Activity(action: "Viewed", detail: "", contributor: "")); decoded.updatedAt = Date()
        XCTAssertTrue(decoded.checkoutReviewIsCurrent)
        decoded.accessItems[0].recipient = "Someone else"; XCTAssertFalse(decoded.checkoutReviewIsCurrent)
    }
    func testMissingReadingAndIncompleteAccessPreventFinalReview() {
        var record = completeCase()
        record.checkout?.meters[0].exclusionReason = ""
        record.accessItems[0].method = ""
        XCTAssertTrue(record.checkoutGaps.contains { $0.area == .meters })
        XCTAssertTrue(record.checkoutGaps.contains { $0.area == .keys })
        XCTAssertThrowsError(try record.finishCheckoutReview())
        record.meters = [MeterReading(type: "Water", reading: "00123", confirmedByUser: false)]
        XCTAssertTrue(record.checkoutGaps.contains { $0.area == .meters })
        record.meters[0].confirmedByUser = true
        XCTAssertFalse(record.checkoutGaps.contains { $0.area == .meters })
    }
    func testDeletedComparisonEvidenceIsFlaggedRatherThanLosingObservation() throws {
        var record = completeCase()
        let before = Evidence(kind: .document, label: "Inventory")
        let after = Evidence(roomID: record.rooms[0].id, kind: .photo, label: "Window")
        record.evidence = [before, after]
        let pair = EvidenceComparison(beforeID: before.id, afterID: after.id, observation: "Same mark visible")
        record.checkout?.comparisons = [pair]
        XCTAssertTrue(record.validComparison(pair)); try record.finishCheckoutReview()
        record.evidence.removeAll { $0.id == before.id }
        XCTAssertFalse(record.checkoutReviewIsCurrent)
        XCTAssertTrue(record.checkoutGaps.contains { $0.area == .comparisons })
        XCTAssertEqual(record.checkout?.comparisons[0].observation, "Same mark visible")
    }
}
