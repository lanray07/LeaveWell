import SwiftUI

struct CaseView: View {
    let caseID: UUID
    var body: some View { CheckoutWorkspaceView(caseID: caseID) }
}

struct CheckoutWorkspaceView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var editing = false
    @State private var error: String?
    var body: some View {
        Group {
            if let record = store.record(caseID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(record.nickname).font(.largeTitle.bold())
                        Text(record.address).foregroundStyle(.secondary)
                        Label(record.moveDate.formatted(date: .long, time: .omitted), systemImage: "calendar")
                        Surface {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(L("Your checkout, one connected record")).font(.title2.bold())
                                Text(L("Work through each room, explain changes, then review readings and access handover. Saved work stays available as you go."))
                                if record.checkout == nil {
                                    Button(L("Start checkout walkthrough")) { start() }.buttonStyle(PrimaryButton())
                                    Text(L("Existing files and checklists are kept. Previous checklist ticks are not treated as documented fixture observations.")).font(.footnote).foregroundStyle(.secondary)
                                } else {
                                    Label(record.checkoutReviewIsCurrent ? L("Current handover review saved") : L("Handover review still needed"), systemImage: record.checkoutReviewIsCurrent ? "checkmark.seal" : "list.bullet.clipboard")
                                        .font(.headline).foregroundStyle(Theme.accent)
                                    Text(L("Areas needing attention") + ": \(record.checkoutGaps.count)").font(.subheadline)
                                }
                            }
                        }
                        if record.checkout != nil {
                            Text(L("1 · Walk the property")).font(.title2.bold())
                            if record.rooms.isEmpty { Button(L("Add rooms in property details")) { editing = true } }
                            ForEach(record.rooms) { room in
                                NavigationLink { RoomCheckoutView(caseID: caseID, roomID: room.id) } label: {
                                    let checked = room.items.filter { item in record.fixtureReview(roomID: room.id, fixture: item).map(record.validFixtureReview) ?? false }.count
                                    Surface {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack { Text(room.name).font(.headline); Spacer(); Image(systemName: "arrow.right") }
                                            Text("\(checked) / \(room.items.count) " + L("documented fixture checks")).font(.caption)
                                            ProgressView(value: Double(checked), total: Double(max(room.items.count, 1)))
                                        }.foregroundStyle(.primary)
                                    }
                                }.buttonStyle(.plain)
                            }
                            Text(L("2 · Explain what changed")).font(.title2.bold())
                            NavigationLink { ComparisonView(caseID: caseID) } label: {
                                FeatureRow(title: L("Evidence comparison board"), subtitle: L("Pair original inventory records with current photographs"), symbol: "rectangle.split.2x1")
                            }.buttonStyle(.plain)
                            Text(L("3 · Close the handover")).font(.title2.bold())
                            NavigationLink { CheckoutRequirementsView(caseID: caseID) } label: {
                                FeatureRow(title: L("Readings and access scope"), subtitle: L("Record what applies to this property, including exceptions"), symbol: "key.horizontal")
                            }.buttonStyle(.plain)
                            NavigationLink { HandoverReviewView(caseID: caseID) } label: {
                                Label(L("Review handover & prepare report"), systemImage: "list.bullet.clipboard").frame(maxWidth: .infinity)
                            }.buttonStyle(PrimaryButton())
                        }
                        Divider()
                        NavigationLink { PlanView(caseID: caseID) } label: { Label(L("Preparation dates & reminders"), systemImage: "calendar.badge.clock") }
                        NavigationLink { CaseRecordsView(caseID: caseID) } label: { Label(L("All property records & tools"), systemImage: "folder") }
                        Text(L("A review is your record of checks, not a certification of condition or a deposit decision.")).font(.footnote).foregroundStyle(.secondary)
                    }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
                }.background(Theme.background).navigationTitle(L("Checkout workspace")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button(L("Property details")) { editing = true } }
                    .sheet(isPresented: $editing) { PropertyEditor(record: record) }
            } else { ContentUnavailableView(L("Record unavailable"), systemImage: "folder") }
        }.errorAlert($error)
    }
    private func start() {
        do { try store.update(caseID, action: "Checkout started") { if $0.checkout == nil { $0.checkout = CheckoutSession() } } }
        catch { self.error = error.localizedDescription }
    }
}

struct RoomCheckoutView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    let roomID: UUID
    var body: some View {
        List {
            if let record = store.record(caseID), let room = record.rooms.first(where: { $0.id == roomID }) {
                Section {
                    Text(L("Look, document, then review")).font(.title2.bold())
                    Text(L("Start at the doorway and follow the fixtures in order. Each check keeps its own observation and evidence links. A photo alone does not complete a check."))
                }
                Section(L("Fixture route")) {
                    ForEach(Array(room.items.enumerated()), id: \.element) { index, fixture in
                        NavigationLink { FixtureReviewView(caseID: caseID, roomID: roomID, fixture: fixture) } label: {
                            let review = record.fixtureReview(roomID: roomID, fixture: fixture)
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(index + 1)").font(.title3.monospacedDigit()).foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L(fixture)).font(.headline)
                                    Text(review.map { record.validFixtureReview($0) ? L($0.outcome.title) : L("Needs attention") } ?? L("Not checked")).font(.caption).foregroundStyle(.secondary)
                                    if let review { Text(review.observation).font(.caption).lineLimit(2) }
                                }
                                Spacer()
                                if let review, record.validFixtureReview(review) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                            }.padding(.vertical, 6)
                        }
                    }
                }
                Section {
                    NavigationLink(L("Room evidence & original checklist")) { RoomView(caseID: caseID, roomID: roomID) }
                    NavigationLink(L("Compare move-in and move-out evidence")) { ComparisonView(caseID: caseID) }
                }
            }
        }.navigationTitle(store.record(caseID)?.rooms.first { $0.id == roomID }?.name ?? L("Room"))
    }
}

struct FixtureReviewView: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let caseID: UUID
    let roomID: UUID
    let fixture: String
    @State private var outcome = FixtureOutcome.checked
    @State private var observation = ""
    @State private var selected: Set<UUID> = []
    @State private var capture: CaptureSelection?
    @State private var error: String?
    @State private var loaded = false
    @State private var include = true
    var body: some View {
        Form {
            if let record = store.record(caseID) {
                Section {
                    Text(L("Describe only what you observed. Choose a reason when a fixture does not apply."))
                    Picker(L("Check outcome"), selection: $outcome) { ForEach(FixtureOutcome.allCases, id: \.self) { Text(L($0.title)).tag($0) } }
                    TextField(L("Observation or reason"), text: $observation, axis: .vertical).lineLimit(3...10)
                }
                Section(L("Evidence linked to this fixture")) {
                    Button(L("Capture or import evidence")) { capture = CaptureSelection(roomID: roomID, label: fixture, kind: .photo) }
                    ForEach(record.evidence.filter { $0.roomID == roomID }) { item in
                        Toggle(isOn: Binding(get: { selected.contains(item.id) }, set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } })) {
                            VStack(alignment: .leading) { Text(item.label); Text(item.reference).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    ForEach(selected.filter { id in !record.evidence.contains { $0.id == id && $0.roomID == roomID } }.sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                        Button(L("Remove missing evidence link")) { selected.remove(id) }
                    }
                    Text(L("A condition to explain requires a factual note and at least one evidence record. Other checks need a note or evidence; not-applicable checks need a reason.")).font(.footnote)
                }
                Section {
                    Toggle(L("Include fixture observation in report"), isOn: $include)
                    Button(L("Save fixture check")) { save(record) }.disabled(!record.validFixtureReview(draft))
                }
            }
        }.navigationTitle(L(fixture)).sheet(item: $capture) { EvidenceComposer(caseID: caseID, selection: $0) }.errorAlert($error)
            .task {
                guard !loaded else { return }; loaded = true
                if let review = store.record(caseID)?.fixtureReview(roomID: roomID, fixture: fixture) {
                    outcome = review.outcome; observation = review.observation; selected = Set(review.evidenceIDs); include = review.includedInReport
                }
            }
    }
    private var draft: FixtureReview { FixtureReview(roomID: roomID, fixture: fixture, outcome: outcome, observation: observation, evidenceIDs: selected.sorted { $0.uuidString < $1.uuidString }) }
    private func save(_ record: MoveCase) {
        do {
            var value = draft; value.includedInReport = include
            try store.update(caseID, action: "Fixture observation saved", detail: fixture) { record in
                if record.checkout == nil { record.checkout = CheckoutSession() }
                record.checkout?.fixtures.removeAll { $0.roomID == roomID && $0.fixture == fixture }
                record.checkout?.fixtures.append(value)
            }; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
