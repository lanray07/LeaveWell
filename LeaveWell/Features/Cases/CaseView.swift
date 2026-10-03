import SwiftUI

struct CaseView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var editing = false
    @State private var error: String?
    var body: some View {
        Group {
            if let record = store.record(caseID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(record.nickname).font(.largeTitle.bold())
                                Text(record.address).foregroundStyle(.secondary)
                            }
                            Spacer(); SymbolTile(symbol: "door.left.hand.open")
                        }
                        Surface {
                            VStack(alignment: .leading, spacing: 16) {
                                Label(record.moveDate.formatted(date: .long, time: .omitted), systemImage: "calendar")
                                HStack { Text(L("Move-out readiness")).font(.headline); Spacer(); Text(record.readiness.formatted(.percent.precision(.fractionLength(0)))).font(.title2.bold()).foregroundStyle(Theme.accent) }
                                ProgressView(value: record.readiness)
                                NavigationLink { PlanView(caseID: caseID) } label: { Label(L("See your move-out plan"), systemImage: "arrow.right") }
                            }
                        }
                        SectionTitle(title: L("Room by room"))
                        if record.rooms.isEmpty { Text(L("Add rooms in property details to start your walkthrough.")).foregroundStyle(.secondary) }
                        ForEach(record.rooms) { room in
                            NavigationLink { RoomView(caseID: caseID, roomID: room.id) } label: {
                                Surface {
                                    HStack(spacing: 16) {
                                        SymbolTile(symbol: room.category == "Kitchen" ? "oven" : "square.split.2x2")
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(room.name).font(.headline).foregroundStyle(.primary)
                                            Text("\(record.evidence(in: room).count) " + L("evidence items")).font(.caption).foregroundStyle(.secondary)
                                            ProgressView(value: room.progress).frame(maxWidth: 180)
                                        }
                                        Spacer(); Image(systemName: room.progress == 1 ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(Theme.accent)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                        SectionTitle(title: L("The finishing details"))
                        VStack(spacing: 12) {
                            NavigationLink { MetersView(caseID: caseID) } label: { FeatureRow(title: L("Meter readings"), subtitle: "\(record.meters.count) " + L("recorded"), symbol: "gauge.with.dots.needle.50percent") }
                            NavigationLink { KeysView(caseID: caseID) } label: { FeatureRow(title: L("Keys & access"), subtitle: "\(record.accessItems.count) " + L("items"), symbol: "key") }
                            NavigationLink { EvidenceListView(caseID: caseID, documentsOnly: true) } label: { FeatureRow(title: L("Document vault"), subtitle: L("Inventory, receipts and correspondence"), symbol: "folder") }
                            NavigationLink { ComparisonView(caseID: caseID) } label: { FeatureRow(title: L("Move-in vs Move-out"), subtitle: L("Review your inventory alongside current evidence"), symbol: "rectangle.split.2x1") }
                            NavigationLink { EvidenceListView(caseID: caseID) } label: { FeatureRow(title: L("All evidence"), subtitle: L("Search your photos, notes and files"), symbol: "magnifyingglass") }
                            NavigationLink { TimelineView(caseID: caseID) } label: { FeatureRow(title: L("Evidence timeline"), subtitle: L("Your move, in order"), symbol: "clock") }
                            NavigationLink { AssistantView(caseID: caseID) } label: { FeatureRow(title: L("LeaveWell assistant"), subtitle: L("Find what is still to do"), symbol: "bubble.left.and.text.bubble.right") }
                        }.buttonStyle(.plain)
                        NavigationLink { ReportView(caseID: caseID) } label: { Label(L("Prepare evidence report"), systemImage: "doc.richtext").frame(maxWidth: .infinity).padding(18).background(Theme.accent, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(Color(.systemBackground)).font(.headline) }
                        Label(L("Saved on device"), systemImage: "checkmark.shield").font(.footnote).foregroundStyle(.secondary)
                    }.padding(24)
                }.background(Theme.background).navigationTitle(L("Your move")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button(L("Details")) { editing = true } }
                    .sheet(isPresented: $editing) { PropertyEditor(record: record) }
            } else { ContentUnavailableView(L("Record unavailable"), systemImage: "folder") }
        }.errorAlert($error)
    }
}

struct FeatureRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        Surface {
            HStack(spacing: 16) {
                SymbolTile(symbol: symbol)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(.primary); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PlanView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var error: String?
    @State private var reminderMessage: String?
    var body: some View {
        List {
            if let record = store.record(caseID) {
                Section {
                    ProgressView(L("Move-out readiness"), value: record.readiness)
                    Text(L("Mark a task complete when you have reviewed it. Evidence and checklist completion are tracked separately.")).font(.footnote).foregroundStyle(.secondary)
                    Button(L("Enable move-out reminders")) {
                        Task { do { try await ReminderService.schedule(record); reminderMessage = L("Reminders enabled for future dates.") } catch { self.error = error.localizedDescription } }
                    }
                    if let reminderMessage { Text(reminderMessage).font(.footnote) }
                    Button(L("Turn off reminders")) { Task { await ReminderService.cancel(caseID: caseID); reminderMessage = L("Reminders turned off.") } }
                }
                ForEach(["Three weeks before", "One week before", "Final day", "After handover"], id: \.self) { phase in
                    Section(L(phase)) {
                        ForEach(MovePlan.tasks(moveDate: record.moveDate).filter { $0.phase == phase }) { task in
                            Button {
                                do { try store.update(caseID, action: "Checklist updated", detail: task.title) { if $0.completedTasks.contains(task.id) { $0.completedTasks.remove(task.id) } else { $0.completedTasks.insert(task.id) } } }
                                catch { self.error = error.localizedDescription }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: record.completedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(Theme.accent)
                                    VStack(alignment: .leading, spacing: 5) { Text(L(task.title)).foregroundStyle(.primary); Text(task.dueAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
                                }.padding(.vertical, 5)
                            }.accessibilityValue(record.completedTasks.contains(task.id) ? L("Complete") : L("Incomplete"))
                        }
                    }
                }
            }
        }.navigationTitle(L("Your move-out plan")).errorAlert($error)
    }
}

struct TimelineView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    var body: some View {
        List(store.record(caseID)?.activities.sorted { $0.date > $1.date } ?? []) { activity in
            VStack(alignment: .leading, spacing: 6) {
                Text(L(activity.action)).font(.headline)
                if !activity.detail.isEmpty { Text(L(activity.detail)) }
                Text(activity.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                if !activity.contributor.isEmpty { Text(L("Added by") + " " + activity.contributor).font(.caption).foregroundStyle(.secondary) }
            }.padding(.vertical, 6)
        }.navigationTitle(L("Evidence timeline"))
    }
}
