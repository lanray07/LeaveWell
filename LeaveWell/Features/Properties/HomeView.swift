import SwiftUI

struct HomeView: View {
    @Environment(CaseStore.self) private var store
    @State private var showCreate = false
    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(L("A calm move starts here.")).font(.largeTitle.bold()).padding(.top, 8)
                        Text(L("Move out organised. Leave with the evidence.")).font(.title3).foregroundStyle(.secondary)
                        if store.archive.cases.isEmpty {
                            Surface {
                                VStack(alignment: .leading, spacing: 20) {
                                    SymbolTile(symbol: "door.left.hand.open")
                                    Text(L("Your next chapter, well documented.")).font(.title2.bold())
                                    Text(L("Add your property, choose your rooms, and take it one step at a time.")).foregroundStyle(.secondary)
                                    Button(L("Create a move-out record")) { showCreate = true }.buttonStyle(PrimaryButton())
                                }
                            }
                        } else {
                            ForEach(store.archive.cases.sorted { $0.moveDate < $1.moveDate }) { record in
                                NavigationLink { CaseView(caseID: record.id) } label: {
                                    Surface {
                                        VStack(alignment: .leading, spacing: 16) {
                                            HStack { SymbolTile(symbol: "building.2"); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Theme.accent) }
                                            Text(record.nickname).font(.title2.bold()).foregroundStyle(.primary)
                                            Text(record.address).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                            Label(record.moveDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar").font(.subheadline).foregroundStyle(.secondary)
                                            ProgressView(value: record.readiness).tint(Theme.accent)
                                            Text(L("Move-out readiness") + " · " + record.readiness.formatted(.percent.precision(.fractionLength(0)))).font(.caption).foregroundStyle(Theme.accent)
                                        }
                                    }
                                }.buttonStyle(.plain)
                            }
                            Button(L("Add another property")) { showCreate = true }.buttonStyle(PrimaryButton())
                        }
                        Label(L("Private by default. Saved on device."), systemImage: "lock.shield").font(.footnote).foregroundStyle(.secondary)
                    }.padding(24)
                }.background(Theme.background).navigationTitle("LeaveWell").navigationBarTitleDisplayMode(.inline)
                    .sheet(isPresented: $showCreate) { PropertyEditor() }
            }.tabItem { Label(L("My move"), systemImage: "house") }
            NavigationStack { SettingsView() }.tabItem { Label(L("Settings"), systemImage: "gearshape") }
        }
    }
}
