import SwiftUI

struct CheckoutRequirementsView: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let caseID: UUID
    @State private var draft = CheckoutSession()
    @State private var customMeter = ""
    @State private var loaded = false
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Text(L("Set the scope for this property")).font(.title2.bold())
                Text(L("Leave a meter reason blank when a final reading is needed. If a supply is absent or included in another service, record that explicitly."))
            }
            Section(L("Expected meters")) {
                ForEach($draft.meters) { $meter in
                    VStack(alignment: .leading) {
                        Text(L(meter.type)).font(.headline)
                        TextField(L("Not applicable reason (otherwise reading required)"), text: $meter.exclusionReason, axis: .vertical)
                    }
                }
                HStack {
                    TextField(L("Additional meter type"), text: $customMeter)
                    Button(L("Add")) {
                        let type = customMeter.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !type.isEmpty, !draft.meters.contains(where: { $0.type.caseInsensitiveCompare(type) == .orderedSame }) else { return }
                        draft.meters.append(MeterRequirement(type: type)); customMeter = ""
                    }.disabled(customMeter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                NavigationLink(L("Add or inspect final readings")) { MetersView(caseID: caseID) }
            }
            Section(L("Access inventory")) {
                Toggle(L("I checked that every access item is listed"), isOn: $draft.accessInventoryChecked)
                if store.record(caseID)?.accessItems.isEmpty != false {
                    TextField(L("Why no keys or access items apply"), text: $draft.noAccessReason, axis: .vertical)
                }
                NavigationLink(L("List keys, fobs and access items")) { KeysView(caseID: caseID) }
                ForEach(store.record(caseID)?.accessItems ?? []) { item in
                    NavigationLink { KeyHandoverView(caseID: caseID, itemID: item.id) } label: {
                        VStack(alignment: .leading) {
                            Text("\(item.quantity) " + L(item.type))
                            Text(item.handedOverAt == nil ? L("Handover still to record") : L("Review handover details")).font(.caption)
                        }
                    }
                }
            }
            Section {
                Button(L("Save property scope")) {
                    do {
                        // Merge only the edited scope. Room/comparison edits made while
                        // navigating away from this form must not be overwritten.
                        try store.update(caseID, action: "Handover scope reviewed") { record in
                            if record.checkout == nil { record.checkout = CheckoutSession() }
                            record.checkout?.meters = draft.meters
                            record.checkout?.accessInventoryChecked = draft.accessInventoryChecked
                            record.checkout?.noAccessReason = draft.noAccessReason
                        }; dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            }
        }.navigationTitle(L("Readings & access scope")).errorAlert($error)
            .task { if !loaded { draft = store.record(caseID)?.checkout ?? CheckoutSession(); loaded = true } }
    }
}

struct KeyHandoverView: View {
    @Environment(CaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let caseID: UUID
    let itemID: UUID
    @State private var recipient = ""
    @State private var method = ""
    @State private var quantity = 1
    @State private var date = Date()
    @State private var happened = false
    @State private var loaded = false
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Text(L("Only confirm a handover after it has happened. This records your account; it is not the recipient's signature."))
                Stepper(L("Quantity") + ": \(quantity)", value: $quantity, in: 1...100)
                TextField(L("Recipient"), text: $recipient)
                TextField(L("Handover method"), text: $method)
                DatePicker(L("Handed over at"), selection: $date, in: ...Date())
                Toggle(L("This handover has happened"), isOn: $happened)
                Button(L("Save handover")) {
                    do {
                        try store.update(caseID, action: "Key handover reviewed") { record in
                            guard let index = record.accessItems.firstIndex(where: { $0.id == itemID }) else { return }
                            record.accessItems[index].quantity = quantity; record.accessItems[index].recipient = recipient
                            record.accessItems[index].method = method; record.accessItems[index].handedOverAt = date
                        }; dismiss()
                    } catch { self.error = error.localizedDescription }
                }.disabled(!happened || recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.navigationTitle(L("Confirm access handover")).errorAlert($error)
            .task {
                if !loaded, let item = store.record(caseID)?.accessItems.first(where: { $0.id == itemID }) {
                    recipient = item.recipient; method = item.method; quantity = max(1, min(100, item.quantity))
                    date = min(item.handedOverAt ?? Date(), Date()); happened = item.handedOverAt != nil; loaded = true
                }
            }
    }
}

struct HandoverReviewView: View {
    @Environment(CaseStore.self) private var store
    let caseID: UUID
    @State private var error: String?
    var body: some View {
        List {
            if let record = store.record(caseID) {
                Section {
                    Text(L("Before you close the door")).font(.title2.bold())
                    Text(L("Check the evidence trail, final readings and actual access handover. Missing details remain visible in the report; they are never silently marked complete."))
                    Label(record.checkoutReviewIsCurrent ? L("Review matches current records") : L("Review needed for current records"), systemImage: record.checkoutReviewIsCurrent ? "checkmark.seal" : "exclamationmark.circle")
                    if let date = record.checkout?.reviewedAt {
                        LabeledContent(L("Last review"), value: date.formatted(date: .abbreviated, time: .shortened))
                        if !record.checkoutReviewIsCurrent { Text(L("Records changed after that review, or checks are incomplete. Review again before relying on the earlier checkpoint.")).font(.footnote) }
                    }
                }
                Section(L("Needs attention")) {
                    if record.checkoutGaps.isEmpty { Label(L("No outstanding checks in the configured scope"), systemImage: "checkmark.circle") }
                    ForEach(record.checkoutGaps) { gap in
                        NavigationLink { destination(gap) } label: {
                            VStack(alignment: .leading, spacing: 6) { Text(L(gap.title)).font(.headline); Text(L(gap.detail)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section(L("Inspect the record")) {
                    NavigationLink(L("Fixture observations")) { CheckoutWorkspaceView(caseID: caseID) }
                    NavigationLink(L("Paired evidence & observations")) { ComparisonView(caseID: caseID) }
                    NavigationLink(L("Meter requirements & access inventory")) { CheckoutRequirementsView(caseID: caseID) }
                    NavigationLink(L("All evidence & report inclusion")) { EvidenceListView(caseID: caseID) }
                }
                Section {
                    Button(L("Save review checkpoint")) {
                        do {
                            var reviewed = record
                            try reviewed.finishCheckoutReview()
                            try store.update(caseID, action: "Handover review saved") { $0.checkout = reviewed.checkout }
                        } catch { self.error = error.localizedDescription }
                    }.disabled(record.checkout == nil || !record.checkoutGaps.isEmpty || record.checkoutReviewIsCurrent)
                    Text(L("A checkpoint records that you reviewed this version. Editing the case makes it stale. It is not a legal certification or a guarantee of completeness beyond your configured scope.")).font(.footnote)
                    NavigationLink(L("Prepare handover evidence package")) { ReportView(caseID: caseID) }
                }
            }
        }.navigationTitle(L("Final handover review")).errorAlert($error)
    }
    @ViewBuilder private func destination(_ gap: CheckoutGap) -> some View {
        switch gap.area {
        case .rooms:
            if let roomID = gap.roomID { RoomCheckoutView(caseID: caseID, roomID: roomID) }
            else { CheckoutWorkspaceView(caseID: caseID) }
        case .meters, .keys: CheckoutRequirementsView(caseID: caseID)
        case .comparisons: ComparisonView(caseID: caseID)
        }
    }
}
