#if DEBUG
import SwiftUI
import UIKit

/// Only compiled into Debug. Captures production views with clearly fictional records.
struct MarketingCapture: View {
    @Environment(CaseStore.self) private var store
    let route: String
    @State private var record: MoveCase?
    @State private var error: String?
    var body: some View {
        Group {
            if let record {
                if route == "home" { HomeView() }
                else {
                    NavigationStack {
                        Group {
                            switch route {
                            case "room": RoomView(caseID: record.id, roomID: record.rooms[0].id)
                            case "evidence": EvidenceListView(caseID: record.id)
                            case "notes": EvidenceDetailView(caseID: record.id, evidenceID: record.evidence.first { $0.kind == .note }!.id)
                            case "meters": MetersView(caseID: record.id)
                            case "keys": KeysView(caseID: record.id)
                            case "documents": EvidenceListView(caseID: record.id, documentsOnly: true)
                            case "comparison": ComparisonView(caseID: record.id)
                            case "plan": PlanView(caseID: record.id)
                            case "report": ReportView(caseID: record.id)
                            case "checkout": CheckoutWorkspaceView(caseID: record.id)
                            case "walkthrough": RoomCheckoutView(caseID: record.id, roomID: record.rooms[0].id)
                            case "handover": HandoverReviewView(caseID: record.id)
                            case "pair": EvidencePairView(record: record, beforeID: record.evidence.first { $0.kind == .document }?.id, afterID: record.evidence.first { $0.kind == .photo }?.id).padding(24).navigationTitle(L("Evidence pair · Demo"))
                            default: CaseView(caseID: record.id)
                            }
                        }
                    }
                }
            } else if let error { Text(error) }
            else { ProgressView() }
        }
        .task {
            do {
                if let existing = store.archive.cases.first(where: { $0.nickname == L("Willow flat · Demo") }) { record = existing }
                else { let demo = try await Self.makeDemo(store: store); try store.add(demo); record = demo }
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let ready = ["route": route, "bundleLocale": Bundle.main.preferredLocalizations.first ?? "en-GB", "locale": Locale.current.identifier]
                try JSONSerialization.data(withJSONObject: ready).write(to: documents.appendingPathComponent("MarketingReady-" + route))
            } catch { self.error = error.localizedDescription }
        }
    }
    @MainActor private static func makeDemo(store: CaseStore) async throws -> MoveCase {
        let date = ISO8601DateFormatter().date(from: "2026-10-24T09:30:00Z")!
        var demo = MoveCase(now: date.addingTimeInterval(-86400 * 21))
        demo.nickname = L("Willow flat · Demo"); demo.address = L("Example property, England")
        demo.tenant = L("Alex · Demo"); demo.moveDate = date; demo.tenancyEndDate = date
        var kitchen = Room(name: L("Kitchen"), category: "Kitchen")
        kitchen.reviewedItems = ["Whole room", "Walls", "Ceiling", "Flooring", "Windows", "Doors"]
        var living = Room(name: L("Living room"), category: "Living room")
        living.reviewedItems = Set(living.items)
        demo.rooms = [kitchen, living, Room(name: L("Bedroom"), category: "Bedroom"), Room(name: L("Bathroom"), category: "Bathroom")]
        let photoURL = Bundle.main.url(forResource: "DemoKitchen", withExtension: "png")!
        let original = try await store.vault.importFile(at: photoURL, origin: .imported, capturedAt: nil)
        demo.evidence.append(Evidence(roomID: kitchen.id, kind: .photo, label: L("Kitchen · whole room"), notes: L("Fictional demonstration photograph. Worktops and sink photographed from the doorway."), original: original, contributor: demo.tenant, now: date))
        demo.evidence.append(Evidence(roomID: kitchen.id, kind: .note, label: L("Worktop edge · observation"), notes: L("Small chip at the front edge beside the sink. I noted it in the move-in inventory and photographed the same area before leaving. Demo record."), condition: .issue, contributor: demo.tenant, now: date.addingTimeInterval(120)))
        demo.evidence.append(Evidence(roomID: living.id, kind: .note, label: L("Living room · final check"), notes: L("Belongings removed. Windows closed. Radiator and sockets checked. Demo record."), contributor: demo.tenant, now: date.addingTimeInterval(240)))
        for (label, text) in [("Move-in inventory · Demo", "Fictional inventory: kitchen worktop edge has a small chip beside the sink."), ("Cleaning receipt · Demo", "Fictional cleaning receipt for screenshot demonstration only."), ("Checkout confirmation · Demo", "Fictional correspondence: checkout appointment confirmed for 24 October.")] {
            let localizedLabel = L(label); let localizedText = L(text)
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
            let data = renderer.pdfData { context in
                context.beginPage()
                (localizedLabel as NSString).draw(in: CGRect(x: 40, y: 40, width: 515, height: 80), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 24)])
                (localizedText as NSString).draw(in: CGRect(x: 40, y: 140, width: 515, height: 250), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
            }
            let file = try await store.vault.store(data, name: localizedLabel + ".pdf", origin: .imported, capturedAt: nil)
            demo.evidence.append(Evidence(kind: .document, label: localizedLabel, notes: L("Fictional sample document."), original: file, contributor: demo.tenant, now: date.addingTimeInterval(-86400)))
        }
        demo.meters = [MeterReading(type: "Electricity", reading: "04821", serialNumber: "DEMO-E01", notes: L("Final reading checked against the display. Demo record."), recordedAt: date, confirmedByUser: true), MeterReading(type: "Gas", reading: "01276", serialNumber: "DEMO-G01", recordedAt: date, confirmedByUser: true), MeterReading(type: "Water", reading: "00318", recordedAt: date, confirmedByUser: true)]
        demo.accessItems = [AccessItem(type: "Front door key", quantity: 2, method: L("In person"), recipient: L("Agent · Demo"), handedOverAt: date.addingTimeInterval(3600), notes: L("Two keys handed over at the agreed checkout. Demo record.")), AccessItem(type: "Building fob", quantity: 1, method: L("In person"), recipient: L("Agent · Demo"), handedOverAt: date.addingTimeInterval(3600))]
        demo.completedTasks = Set(MovePlan.tasks(moveDate: date).prefix(13).map(\.id))
        demo.checkout = CheckoutSession(startedAt: date)
        demo.checkout?.fixtures = kitchen.items.prefix(6).map { fixture in
            FixtureReview(roomID: kitchen.id, fixture: fixture, outcome: .checked,
                          observation: L("Fictional demo: checked and photographed."), evidenceIDs: [demo.evidence[0].id], reviewedAt: date)
        }
        demo.checkout?.comparisons = [EvidenceComparison(beforeID: demo.evidence.first { $0.kind == .document }!.id,
            afterID: demo.evidence[0].id, observation: L("Fictional demo: the inventory records a chip beside the sink; compare with the current photograph."), createdAt: date)]
        demo.activities = [Activity(action: "Property created", detail: "Willow flat · Demo", contributor: demo.tenant, date: date.addingTimeInterval(-86400*21)), Activity(action: "Evidence added", detail: "Kitchen · whole room", contributor: demo.tenant, date: date), Activity(action: "Meter reading recorded", detail: "Electricity · 04821", contributor: demo.tenant, date: date.addingTimeInterval(600))]
        return demo
    }
}
#endif
