import SwiftUI

struct HomeView: View {
    @Environment(CaseStore.self) private var store
    @State private var creation: Creation?
    @State private var route: Route?
    @State private var creatingPractice = false
    @State private var error: String?

    private enum Creation: String, Identifiable {
        case inventory, manual
        var id: String { rawValue }
    }
    private enum Route: Hashable {
        case inventory(UUID), practice(UUID), checkout(UUID)
    }

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        let records = store.archive.cases.filter { $0.isPracticeRecord != true }
                        Text(L("Your move-out records")).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                        ForEach(records.sorted { $0.moveDate < $1.moveDate }) { record in
                            NavigationLink { CaseView(caseID: record.id) } label: {
                                FeatureRow(title: record.nickname,
                                           subtitle: record.moveDate.formatted(date: .abbreviated, time: .omitted),
                                           symbol: "building.2")
                            }.buttonStyle(.plain)
                        }
                        Surface {
                            VStack(alignment: .leading, spacing: 16) {
                                SymbolTile(symbol: "doc.text.magnifyingglass")
                                Text(L("Start with the inventory you received")).font(.title2.bold())
                                Text(L("Choose what to check, record what you find, and keep both sides together for handover."))
                                    .foregroundStyle(.secondary)
                                Button(L("Start from an inventory")) { creation = .inventory }.buttonStyle(PrimaryButton())
                                Button(L("Start without an inventory")) { creation = .manual }
                                Button(L("Try a fictional inventory"), action: openPractice).disabled(creatingPractice)
                            }
                        }
                        Label(L("Private by default. Saved on device."), systemImage: "lock.shield")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
                }
                .background(Theme.background).navigationTitle("LeaveWell").navigationBarTitleDisplayMode(.inline)
                .sheet(item: $creation) { choice in
                    PropertyEditor(onCreated: { id in
                        route = choice == .inventory ? .inventory(id) : .checkout(id)
                    })
                }
                .navigationDestination(item: $route) { destination in
                    switch destination {
                    case .inventory(let id): InventoryQueueView(caseID: id, opensImporter: true)
                    case .practice(let id): InventoryQueueView(caseID: id, opensPracticeDocument: true)
                    case .checkout(let id): CaseView(caseID: id)
                    }
                }
                .errorAlert($error)
            }.tabItem { Label(L("My move"), systemImage: "house") }
            NavigationStack { SettingsView() }.tabItem { Label(L("Settings"), systemImage: "gearshape") }
        }
    }

    private func openPractice() {
        creatingPractice = true
        Task {
            defer { creatingPractice = false }
            do { route = .practice(try await store.practiceInventory()) }
            catch { self.error = error.localizedDescription }
        }
    }
}
