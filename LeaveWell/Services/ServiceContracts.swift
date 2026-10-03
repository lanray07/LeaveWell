import Foundation

/// Boundaries for a later connected edition. There are no fake online successes.
public struct AccountIdentity: Sendable, Codable { public let id: String; public let displayName: String }
public protocol AuthenticationService: Sendable {
    func signIn() async throws -> AccountIdentity
    func signOut() async throws
    func deleteAccount() async throws
}
public protocol CloudSyncService: Sendable {
    func upload(original: OriginalFile, from url: URL, caseID: UUID) async throws
    func synchronize(_ record: MoveCase) async throws -> MoveCase
    func deleteCase(id: UUID) async throws
}
public struct PrivateShare: Sendable { public let id: String; public let url: URL; public let expiresAt: Date }
public protocol SharingService: Sendable {
    func createShare(caseID: UUID, expiresAt: Date, allowsDownload: Bool) async throws -> PrivateShare
    func revokeShare(id: String) async throws
}
public protocol CollaborationService: Sendable {
    func invite(caseID: UUID, recipient: String) async throws
    func contributions(caseID: UUID) async throws -> [Evidence]
}
public protocol AnalyticsService: Sendable { func record(event: String) async }
public struct NoTrackingAnalytics: AnalyticsService { public func record(event: String) async {} }

public enum TranslationStatus: String, Codable, Sendable { case draft, translated, reviewed }
public struct TranslationRecord: Codable, Sendable {
    public let source: String
    public let translation: String
    public let locale: String
    public let status: TranslationStatus
    public let reviewed: Bool
    public let version: Int
    public let requiresSpecialistReview: Bool
    public var canPublish: Bool { reviewed && status == .reviewed }
}
