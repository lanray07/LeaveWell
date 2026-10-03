import SwiftUI

struct OnboardingView: View {
    let finish: () -> Void
    @State private var page = 0
    private let pages: [(String, String, String)] = [
        ("Move out with confidence", "Create an organised record of your rental property's condition before handing back the keys.", "person.crop.rectangle"),
        ("Know what to capture", "LeaveWell guides you room by room so important details don't get forgotten.", "checklist"),
        ("Turn evidence into a report", "Keep your photos, notes, meter readings and documents organised in one professional move-out report.", "doc.richtext"),
        ("Your home. Your evidence. Your privacy.", "Your records stay on this device. You choose what to include and when to share. Keep an export somewhere safe before changing or losing your phone.", "lock.shield")
    ]
    var body: some View {
        VStack(spacing: 20) {
            HStack { Text("LeaveWell").font(.title3.bold()); Spacer(); Text(L("Move out organised.")).font(.caption).foregroundStyle(.secondary) }.padding(.horizontal, 28)
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 36).fill(Theme.accent.opacity(0.08)).frame(height: 270)
                                Image(systemName: pages[index].2).font(.system(size: 96, weight: .light)).foregroundStyle(Theme.accent)
                                if index == 0 {
                                    Image(systemName: "camera.fill").font(.system(size: 30)).foregroundStyle(Theme.accent)
                                        .padding(14).background(Theme.card, in: Circle()).offset(x: 58, y: 38)
                                }
                            }.accessibilityHidden(true)
                            Text(L(pages[index].0)).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                            Text(L(pages[index].1)).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            if index == 1 {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(["Rooms and appliances", "Meters and access items", "Cleaning and supporting documents"], id: \.self) { item in Label(L(item), systemImage: "checkmark.circle") }
                                }.foregroundStyle(Theme.accent)
                            }
                        }.padding(28)
                    }.tag(index)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 8) { ForEach(pages.indices, id: \.self) { index in Capsule().fill(index == page ? Theme.accent : Color.secondary.opacity(0.25)).frame(width: index == page ? 24 : 8, height: 8) } }.accessibilityLabel(L("Introduction"))
            Button(page == 3 ? L("Create my move-out record") : (page == 0 ? L("Get Started") : L("Continue"))) {
                if page == 3 { finish() } else { page += 1 }
            }.buttonStyle(PrimaryButton()).padding(.horizontal, 28).padding(.bottom, 16)
        }.background(Theme.background)
    }
}

#Preview("LeaveWell onboarding") { OnboardingView {} }
