import Foundation

public enum FixtureOutcome: String, Codable, CaseIterable, Sendable {
    case checked, change, notApplicable
    public var title: String {
        switch self {
        case .checked: "Checked condition"
        case .change: "Condition to explain"
        case .notApplicable: "Not applicable"
        }
    }
}

public struct FixtureReview: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var roomID: UUID
    public var fixture: String
    public var outcome: FixtureOutcome
    public var observation: String
    public var evidenceIDs: [UUID]
    public var reviewedAt: Date
    public var includedInReport = true
    public init(roomID: UUID, fixture: String, outcome: FixtureOutcome, observation: String,
                evidenceIDs: [UUID], reviewedAt: Date = Date()) {
        self.roomID = roomID; self.fixture = fixture; self.outcome = outcome
        self.observation = observation; self.evidenceIDs = evidenceIDs; self.reviewedAt = reviewedAt
    }
}

public struct EvidenceComparison: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var beforeID: UUID
    public var afterID: UUID
    public var observation: String
    public var createdAt: Date
    public var includedInReport = true
    public init(beforeID: UUID, afterID: UUID, observation: String, createdAt: Date = Date()) {
        self.beforeID = beforeID; self.afterID = afterID; self.observation = observation; self.createdAt = createdAt
    }
}

public struct MeterRequirement: Codable, Equatable, Sendable, Identifiable {
    public var id: String { type }
    public var type: String
    public var exclusionReason: String
    public init(type: String, exclusionReason: String = "") { self.type = type; self.exclusionReason = exclusionReason }
}

public struct CheckoutSession: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var fixtures: [FixtureReview] = []
    public var comparisons: [EvidenceComparison] = []
    public var meters = ["Electricity", "Gas", "Water"].map { MeterRequirement(type: $0) }
    public var accessInventoryChecked = false
    public var noAccessReason = ""
    public var reviewedAt: Date?
    public var reviewedContent: Data?
    public init(startedAt: Date = Date()) { self.startedAt = startedAt }
}

public struct CheckoutGap: Identifiable, Equatable, Sendable {
    public enum Area: String, Sendable { case rooms, meters, keys, comparisons }
    public var id: String
    public var area: Area
    public var roomID: UUID?
    public var title: String
    public var detail: String
}

extension MoveCase {
    public func fixtureReview(roomID: UUID, fixture: String) -> FixtureReview? {
        checkout?.fixtures.first { $0.roomID == roomID && $0.fixture == fixture }
    }
    public func validFixtureReview(_ review: FixtureReview) -> Bool {
        let note = !review.observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let linked = review.evidenceIDs.compactMap { id in evidence.first { $0.id == id && $0.roomID == review.roomID } }
        guard linked.count == Set(review.evidenceIDs).count else { return false }
        switch review.outcome {
        case .notApplicable: return note
        case .checked: return note || !linked.isEmpty
        case .change: return note && !linked.isEmpty
        }
    }
    public func validComparison(_ comparison: EvidenceComparison) -> Bool {
        guard comparison.beforeID != comparison.afterID,
              !comparison.observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let before = evidence.first(where: { $0.id == comparison.beforeID }),
              let after = evidence.first(where: { $0.id == comparison.afterID }) else { return false }
        return [.photo, .document].contains(before.kind) && after.kind == .photo
    }
    public var checkoutGaps: [CheckoutGap] {
        var gaps: [CheckoutGap] = []
        if rooms.isEmpty { gaps.append(.init(id: "rooms", area: .rooms, title: "Add a room", detail: "Set up the rooms in property details before starting the walkthrough.")) }
        for room in rooms {
            let pending = room.items.filter { item in
                guard let review = fixtureReview(roomID: room.id, fixture: item) else { return true }
                return !validFixtureReview(review)
            }
            if !pending.isEmpty { gaps.append(.init(id: room.id.uuidString, area: .rooms, roomID: room.id, title: room.name,
                detail: "\(pending.count) fixture checks need an observation or linked evidence.")) }
        }
        let session = checkout ?? CheckoutSession()
        for requirement in session.meters where requirement.exclusionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !meters.contains(where: { $0.type == requirement.type && $0.isValid }) {
                gaps.append(.init(id: "meter-" + requirement.type, area: .meters, title: requirement.type,
                                  detail: "Add a confirmed reading or explain why this meter is not applicable."))
            }
        }
        if !session.accessInventoryChecked {
            gaps.append(.init(id: "access-check", area: .keys, title: "Check the access inventory", detail: "Confirm that all keys, fobs and other access items are listed."))
        }
        if accessItems.isEmpty && session.noAccessReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            gaps.append(.init(id: "access-empty", area: .keys, title: "Record access items", detail: "List the items to hand over or explain why none apply."))
        }
        for item in accessItems where item.quantity < 1 || item.handedOverAt == nil || (item.handedOverAt ?? .distantFuture) > Date() || item.recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || item.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            gaps.append(.init(id: item.id.uuidString, area: .keys, title: item.type, detail: "Record quantity, recipient, method and the actual handover date."))
        }
        for comparison in session.comparisons where !validComparison(comparison) {
            gaps.append(.init(id: comparison.id.uuidString, area: .comparisons, title: "Repair an evidence comparison", detail: "A linked record is missing or the observation is incomplete."))
        }
        return gaps
    }
    /// Canonical content checkpoint, not a signature or proof of authenticity.
    /// Ignore activity timestamps; any actual case-content change makes review stale.
    public func checkoutContent() throws -> Data {
        var copy = self
        copy.activities = []; copy.updatedAt = copy.createdAt
        copy.checkout?.reviewedAt = nil; copy.checkout?.reviewedContent = nil
        let tasks = copy.completedTasks.sorted(); copy.completedTasks = []
        let roomChecks = copy.rooms.map { $0.reviewedItems.sorted() }
        for index in copy.rooms.indices { copy.rooms[index].reviewedItems = [] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(CheckoutContent(record: copy, completedTasks: tasks, roomChecks: roomChecks))
    }
    public var checkoutReviewIsCurrent: Bool {
        guard let saved = checkout?.reviewedContent, checkout?.reviewedAt != nil, checkoutGaps.isEmpty else { return false }
        return (try? checkoutContent()) == saved
    }
    public mutating func finishCheckoutReview(at date: Date = Date()) throws {
        guard checkout != nil, checkoutGaps.isEmpty else { throw CheckoutError.incomplete }
        let content = try checkoutContent()
        checkout?.reviewedAt = date; checkout?.reviewedContent = content
    }
}

public enum CheckoutError: Error { case incomplete }

private struct CheckoutContent: Encodable {
    var record: MoveCase
    var completedTasks: [String]
    var roomChecks: [[String]]
}
