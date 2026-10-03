import Foundation
import UserNotifications

enum ReminderService {
    static func refreshIfScheduled(_ record: MoveCase) async throws {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard pending.contains(where: { $0.identifier.hasPrefix(record.id.uuidString + "-") }) else { return }
        try await schedule(record)
    }
    static func schedule(_ record: MoveCase) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw ReminderError.denied }
        await cancel(caseID: record.id)
        let reminders = [(-7, "Review your original inventory."), (-1, "Your final walkthrough is tomorrow."), (0, "Remember your final meter readings.")]
        for (offset, text) in reminders {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: record.moveDate),
                  let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day), date > Date() else { continue }
            let content = UNMutableNotificationContent(); content.title = L("LeaveWell reminder"); content.body = L(text); content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            try await center.add(UNNotificationRequest(identifier: record.id.uuidString + "-\(offset)", content: content,
                                                       trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }
    }
    static func cancel(caseID: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [-7, -1, 0].map { caseID.uuidString + "-\($0)" })
    }
}
enum ReminderError: LocalizedError {
    case denied
    var errorDescription: String? { L("Notifications are disabled. You can enable them in iOS Settings.") }
}
