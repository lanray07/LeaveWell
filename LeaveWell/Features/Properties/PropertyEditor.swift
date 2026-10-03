import SwiftUI

struct PropertyEditor: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MoveCase
    @State private var selectedRooms: Set<String>
    @State private var customRoom = ""
    @State private var checkoutEnabled = false
    @State private var error: String?
    private let editing: Bool
    init(record: MoveCase? = nil) {
        _draft = State(initialValue: record ?? MoveCase())
        _selectedRooms = State(initialValue: record == nil ? Set(["Kitchen", "Bedroom", "Bathroom", "Living room"]) : [])
        _checkoutEnabled = State(initialValue: record?.checkoutAt != nil)
        editing = record != nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(L("Your property")) {
                    TextField(L("Property nickname"), text: $draft.nickname)
                    TextField(L("Address"), text: $draft.address, axis: .vertical).textContentType(.fullStreetAddress)
                    TextField(L("Your name"), text: $draft.tenant).textContentType(.name)
                    Picker(L("Country"), selection: $draft.countryCode) {
                        Text(L("United Kingdom")).tag("GB"); Text(L("Other country")).tag("OTHER")
                    }.onChange(of: draft.countryCode) { _, code in draft.jurisdictionCode = code == "GB" ? "GB-ENG" : "OTHER" }
                    if draft.countryCode == "GB" {
                        Picker(L("Region"), selection: $draft.jurisdictionCode) { ForEach(Jurisdictions.supported.filter { $0.country == "GB" }) { Text(L($0.title)).tag($0.id) } }
                    }
                    Picker(L("Property type"), selection: $draft.propertyType) { ForEach(["Flat", "House", "Studio", "Room", "Other"], id: \.self) { Text(L($0)).tag($0) } }
                    Toggle(L("Furnished"), isOn: $draft.furnished)
                    Stepper(L("Tenants") + " · \(draft.tenantCount)", value: $draft.tenantCount, in: 1...100)
                }
                Section(L("Your dates")) {
                    DatePicker(L("Tenancy end date"), selection: $draft.tenancyEndDate, displayedComponents: .date)
                    DatePicker(L("Move-out date"), selection: $draft.moveDate, displayedComponents: .date)
                    Toggle(L("Checkout appointment arranged"), isOn: $checkoutEnabled)
                    if checkoutEnabled { DatePicker(L("Checkout appointment"), selection: Binding(get: { draft.checkoutAt ?? draft.moveDate }, set: { draft.checkoutAt = $0 })) }
                }
                Section(L("Optional details")) {
                    TextField(L("Deposit amount"), text: $draft.depositAmount).keyboardType(.decimalPad)
                    TextField(L("Deposit scheme"), text: $draft.depositScheme)
                    TextField(L("Landlord / agent name"), text: $draft.agentName)
                    TextField(L("Landlord / agent contact"), text: $draft.agentContact)
                    TextField(L("Key-return method"), text: $draft.keyReturnMethod)
                }
                Section(L("Rooms to document")) {
                    if editing {
                        ForEach(draft.rooms) { room in Text(room.name) }
                    } else {
                        ForEach(RoomGuide.categories, id: \.self) { category in
                            Toggle(L(category), isOn: Binding(get: { selectedRooms.contains(category) }, set: { if $0 { selectedRooms.insert(category) } else { selectedRooms.remove(category) } }))
                        }
                    }
                    HStack {
                        TextField(L("Custom room name"), text: $customRoom)
                        Button(L("Add")) {
                            let name = customRoom.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty { draft.rooms.append(Room(name: name)); customRoom = "" }
                        }.disabled(customRoom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !editing { ForEach(draft.rooms) { Text($0.name) } }
                }
            }.navigationTitle(editing ? L("Property details") : L("Your move-out record"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L("Save"), action: save).disabled(draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }.errorAlert($error)
        }
    }
    private func save() {
        do {
            if !checkoutEnabled { draft.checkoutAt = nil }
            else if draft.checkoutAt == nil { draft.checkoutAt = draft.moveDate }
            if editing {
                // Merge property fields with the latest evidence, avoiding stale sheet snapshots.
                try store.update(draft.id, action: "Property details updated") { current in
                    let rooms = current.rooms + draft.rooms.filter { new in !current.rooms.contains { $0.id == new.id } }
                    let evidence = current.evidence; let meters = current.meters; let keys = current.accessItems
                    let activities = current.activities; let tasks = current.completedTasks
                    current = draft; current.rooms = rooms; current.evidence = evidence; current.meters = meters
                    current.accessItems = keys; current.activities = activities; current.completedTasks = tasks
                }
            } else {
                draft.rooms.insert(contentsOf: RoomGuide.categories.filter { selectedRooms.contains($0) }.map { Room(name: L($0), category: $0) }, at: 0)
                draft.activities.append(Activity(action: "Record created", detail: draft.nickname, contributor: draft.tenant))
                try store.add(draft)
            }
            Task { await ReminderService.cancel(caseID: draft.id) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
