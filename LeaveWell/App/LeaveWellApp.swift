import SwiftUI

@main
struct LeaveWellApp: App {
    @State private var store: CaseStore?
    @State private var startupError: String?
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    var body: some Scene {
        WindowGroup {
            ZStack {
                if let store {
                    if !store.ready {
                        VStack(spacing: 20) {
                            if let error = store.errorMessage {
                                ContentUnavailableView(L("Records unavailable"), systemImage: "lock.doc", description: Text(error))
                                Button(L("Retry")) { Task { await store.load() } }
                            } else { ProgressView(L("Opening your records…")) }
                        }
                    } else if !onboardingComplete {
                        OnboardingView { onboardingComplete = true }
                    } else { HomeView().environment(store) }
                } else if let startupError {
                    ContentUnavailableView(L("Unable to open LeaveWell"), systemImage: "exclamationmark.triangle", description: Text(startupError))
                } else { ProgressView() }
                if appLockEnabled && !lock.unlocked {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 24) {
                        Image(systemName: "lock.shield").font(.system(size: 60)).foregroundStyle(Theme.accent)
                        Text(L("Your evidence stays private")).font(.title2.bold())
                        if let message = lock.message { Text(message).foregroundStyle(.secondary) }
                        Button(L("Unlock LeaveWell")) { Task { await lock.unlock() } }.buttonStyle(PrimaryButton())
                    }.padding(32)
                }
            }
            .tint(Theme.accent)
            .task {
                if appLockEnabled { await lock.unlock() }
                guard store == nil else { return }
                do {
                    try ExportWorkspace.clear()
                    let newStore = try CaseStore(); store = newStore; await newStore.load()
                } catch { startupError = error.localizedDescription }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active && appLockEnabled { lock.unlocked = false }
            }
            .onChange(of: appLockEnabled) { _, enabled in
                if enabled { lock.unlocked = false; Task { await lock.unlock() } }
            }
        }
    }
}
