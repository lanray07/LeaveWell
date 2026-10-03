import Foundation

public enum EvidenceKind: String, Codable, CaseIterable, Sendable { case photo, video, audio, document, note }
public enum Condition: String, Codable, CaseIterable, Sendable { case noIssue, issue, notApplicable }
public enum CaptureOrigin: String, Codable, Sendable { case camera, imported, recorded, scanned }
public enum SyncState: String, Codable, Sendable { case local, syncing, backedUp, failed }

/// Original metadata is write-once. Captured time is never inferred from import time.
public struct OriginalFile: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let relativePath: String
    public let originalName: String
    public let sha256: String
    public let byteCount: Int
    public let capturedAt: Date?
    public let importedAt: Date?
    public let createdAt: Date
    public let origin: CaptureOrigin
    public init(id: UUID = UUID(), relativePath: String, originalName: String, sha256: String,
                byteCount: Int, capturedAt: Date? = nil, importedAt: Date? = nil,
                createdAt: Date = Date(), origin: CaptureOrigin) {
        self.id = id; self.relativePath = relativePath; self.originalName = originalName
        self.sha256 = sha256; self.byteCount = byteCount; self.capturedAt = capturedAt
        self.importedAt = importedAt; self.createdAt = createdAt; self.origin = origin
    }
}

public struct Evidence: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var roomID: UUID?
    public var kind: EvidenceKind
    public var label: String
    public var notes: String
    public var transcript: String
    public var condition: Condition
    public let original: OriginalFile?
    public var derivatives: [OriginalFile]
    public let createdAt: Date
    public var updatedAt: Date
    public var contributor: String
    public var includedInReport: Bool
    public var syncState: SyncState
    public var suggestion: String?
    public var suggestionConfirmed: Bool
    public var reference: String { "EV-" + id.uuidString }
    public init(id: UUID = UUID(), roomID: UUID? = nil, kind: EvidenceKind, label: String,
                notes: String = "", transcript: String = "", condition: Condition = .noIssue,
                original: OriginalFile? = nil, contributor: String = "", now: Date = Date()) {
        self.id = id; self.roomID = roomID; self.kind = kind; self.label = label
        self.notes = notes; self.transcript = transcript; self.condition = condition
        self.original = original; self.derivatives = []; self.createdAt = now; self.updatedAt = now
        self.contributor = contributor; self.includedInReport = true; self.syncState = .local
        self.suggestion = nil; self.suggestionConfirmed = false
    }
}

public struct Room: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var category: String
    public var items: [String]
    public var reviewedItems: Set<String> = []
    public var notes = ""
    public init(name: String, category: String = "Other") {
        self.name = name; self.category = category
        self.items = RoomGuide.items(for: category)
    }
    public var progress: Double { items.isEmpty ? 0 : Double(reviewedItems.intersection(items).count) / Double(items.count) }
}

public enum RoomGuide {
    public static let categories = ["Entrance / Hallway", "Living room", "Kitchen", "Bedroom", "Bathroom",
                                   "Utility room", "Storage", "Balcony", "Garden", "Garage", "Shed", "Parking space", "Other"]
    public static func items(for category: String) -> [String] {
        let base = ["Whole room", "Walls", "Ceiling", "Flooring", "Windows", "Doors"]
        switch category {
        case "Kitchen": return base + ["Worktops", "Cupboards", "Sink", "Oven", "Hob", "Fridge / freezer", "Washing machine", "Dishwasher"]
        case "Bathroom": return base + ["Basin", "Bath / shower", "Toilet", "Ventilation"]
        case "Bedroom", "Living room": return base + ["Furniture", "Radiators", "Sockets"]
        case "Garden", "Balcony", "Parking space": return ["Whole area", "Ground surface", "Boundaries", "Fixtures"]
        default: return base + ["Other fixtures"]
        }
    }
}

public struct MeterReading: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var type: String
    public var reading: String
    public var serialNumber: String
    public var notes: String
    public var recordedAt: Date
    public var evidenceID: UUID?
    public var confirmedByUser: Bool
    public init(type: String, reading: String, serialNumber: String = "", notes: String = "",
                recordedAt: Date = Date(), evidenceID: UUID? = nil, confirmedByUser: Bool) {
        self.type = type; self.reading = reading; self.serialNumber = serialNumber; self.notes = notes
        self.recordedAt = recordedAt; self.evidenceID = evidenceID; self.confirmedByUser = confirmedByUser
    }
    public var isValid: Bool { confirmedByUser && !reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

public struct AccessItem: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var type: String
    public var quantity: Int
    public var method: String
    public var recipient: String
    public var handedOverAt: Date?
    public var notes: String
    public var evidenceID: UUID?
    public init(type: String, quantity: Int = 1, method: String = "", recipient: String = "",
                handedOverAt: Date? = nil, notes: String = "", evidenceID: UUID? = nil) {
        self.type = type; self.quantity = quantity; self.method = method; self.recipient = recipient
        self.handedOverAt = handedOverAt; self.notes = notes; self.evidenceID = evidenceID
    }
}

public struct Activity: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let action: String
    public let detail: String
    public let contributor: String
    public init(action: String, detail: String, contributor: String, date: Date = Date()) {
        id = UUID(); self.date = date; self.action = action; self.detail = detail; self.contributor = contributor
    }
}

public struct PlanTask: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let phase: String
    public let dueAt: Date
}

public enum MovePlan {
    public static func tasks(moveDate: Date, calendar: Calendar = .current) -> [PlanTask] {
        let phases: [(String, Int, [String])] = [
            ("Three weeks before", -21, ["Review original inventory", "Check unresolved repairs", "Organise supporting documents", "Consider cleaning arrangements"]),
            ("One week before", -7, ["Confirm checkout arrangements", "Collect receipts", "Review previously reported issues", "Check key-return requirements"]),
            ("Final day", 0, ["Remove belongings", "Complete cleaning", "Photograph every room", "Photograph fixtures", "Record meters", "Record keys and fobs", "Complete walkthrough", "Generate report"]),
            ("After handover", 1, ["Record key handover", "Save communications", "Add any proposed deductions", "Add supporting records"])
        ]
        return phases.enumerated().flatMap { index, phase in
            phase.2.enumerated().map { offset, title in
                PlanTask(id: "plan-\(index)-\(offset)", title: title, phase: phase.0,
                         dueAt: calendar.date(byAdding: .day, value: phase.1, to: calendar.startOfDay(for: moveDate)) ?? moveDate)
            }
        }
    }
}

public struct MoveCase: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var nickname = ""
    public var address = ""
    public var tenant = ""
    public var countryCode = "GB"
    public var jurisdictionCode = "GB-ENG"
    public var propertyType = "Flat"
    public var furnished = false
    public var tenancyEndDate = Date()
    public var moveDate = Date()
    public var checkoutAt: Date?
    public var depositAmount = ""
    public var depositScheme = ""
    public var agentName = ""
    public var agentContact = ""
    public var keyReturnMethod = ""
    public var tenantCount = 1
    public var rooms: [Room] = []
    public var evidence: [Evidence] = []
    public var meters: [MeterReading] = []
    public var accessItems: [AccessItem] = []
    public var activities: [Activity] = []
    public var completedTasks: Set<String> = []
    public let createdAt: Date
    public var updatedAt: Date
    public init(now: Date = Date()) { createdAt = now; updatedAt = now }
    public var reference: String { "LW-" + id.uuidString }
    public var readiness: Double {
        let tasks = MovePlan.tasks(moveDate: moveDate)
        return Double(completedTasks.intersection(tasks.map(\.id)).count) / Double(tasks.count)
    }
    public func evidence(in room: Room) -> [Evidence] { evidence.filter { $0.roomID == room.id } }
    public func search(_ query: String) -> [Evidence] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return evidence.sorted { $0.createdAt > $1.createdAt } }
        return evidence.filter { item in
            let room = rooms.first { $0.id == item.roomID }?.name ?? ""
            let text = [item.label, item.notes, item.transcript, room, item.original?.originalName ?? "", item.reference]
                .joined(separator: " ").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return words.allSatisfy { text.contains($0.folding(options: [.diacriticInsensitive], locale: .current)) }
        }.sorted { $0.createdAt > $1.createdAt }
    }
}

public struct Archive: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var cases: [MoveCase] = []
    public init() {}
}

public enum ArchiveError: Error { case unsupportedVersion }
public enum ArchiveCodec {
    public static func encode(_ archive: Archive) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(archive)
    }
    public static func decode(_ data: Data) throws -> Archive {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let result = try decoder.decode(Archive.self, from: data)
        guard result.schemaVersion == 1 else { throw ArchiveError.unsupportedVersion }
        return result
    }
}
