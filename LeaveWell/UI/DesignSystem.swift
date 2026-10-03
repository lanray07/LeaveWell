import SwiftUI
import UIKit

enum Theme {
    static let accent = Color("AccentColor")
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17).padding(.horizontal, 16)
            .background(Theme.accent.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35))
            .foregroundStyle(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SectionTitle: View {
    let title: String
    var body: some View { Text(title).font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8).accessibilityAddTraits(.isHeader) }
}

struct SymbolTile: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol).font(.title2).foregroundStyle(Theme.accent)
            .frame(width: 52, height: 52).background(Theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 15)).accessibilityHidden(true)
    }
}

struct SharePayload: Identifiable { let id = UUID(); let urls: [URL] }
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension View {
    func errorAlert(_ error: Binding<String?>) -> some View {
        alert(L("Something needs attention"), isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } })) {
            Button(L("OK"), role: .cancel) { error.wrappedValue = nil }
        } message: { Text(error.wrappedValue ?? "") }
    }
}
