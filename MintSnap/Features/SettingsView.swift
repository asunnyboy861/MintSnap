import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsService.self) private var settings
    @Environment(StoreService.self) private var store
    @Environment(QuotaService.self) private var quota
    @State private var apiKeyInput = ""
    @State private var keySaved = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Recognition") {
                    SecureField("Your Z.ai / BigModel API key", text: $apiKeyInput, prompt: Text(quota.hasBYOKey ? "Key saved — enter to replace" : "Paste your API key"))
                    HStack {
                        Button("Save Key") { saveKey() }
                            .disabled(apiKeyInput.isEmpty)
                        if quota.hasBYOKey {
                            Button("Remove", role: .destructive) {
                                removeKey()
                            }
                        }
                        if keySaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.mintAccent)
                        }
                    }
                    Text("With your own API key, cloud recognition is unlimited and requests go directly to Z.ai — the key is stored in your device Keychain and never leaves it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Toggle("On-device recognition only", isOn: Binding(
                        get: { !settings.imageUploadAllowed },
                        set: { settings.imageUploadAllowed = !$0 }
                    ))
                    Text("When off, low-confidence scans upload the cropped card photo to cloud AI for identification.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Cloud & Sync") {
                    Toggle("iCloud Sync (Binder)", isOn: Binding(
                        get: { settings.cloudSyncEnabled },
                        set: { settings.cloudSyncEnabled = $0 }
                    ))
                    Text("Takes effect the next time you launch MintSnap. Without iCloud, your binder stays on this device.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Toggle("Weekly Collection Pulse", isOn: Binding(
                        get: { settings.weeklyPulseEnabled },
                        set: {
                            settings.weeklyPulseEnabled = $0
                            if $0 {
                                Task { await AlertEngine.shared.requestNotificationPermission() }
                            } else {
                                AlertEngine.shared.cancelWeeklyPulse()
                            }
                        }
                    ))
                    Text("Sundays at 8:00 PM, MintSnap summarizes how your collection moved this week.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Subscription") {
                    if store.isPro {
                        Label("MintSnap Pro active", systemImage: "crown.fill")
                            .foregroundStyle(Color.cardGold)
                    } else {
                        Text("Free: 5 on-device scans/day · 5 alerts. Pro unlocks unlimited scans, graded tiers and alerts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Link("Manage Subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                }

                Section("Legal") {
                    Link("Privacy Policy", destination: URL(string: "https://zzoutuo.github.io/MintSnap/privacy.html")!)
                    Link("Terms of Use", destination: URL(string: "https://zzoutuo.github.io/MintSnap/terms.html")!)
                    Link("Contact Support", destination: URL(string: "mailto:asunnyboy168@icloud.com?subject=MintSnap%20Support")!)
                }

                Section {
                    Text(appVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("MintSnap shows real sold prices with confidence labels. Prices are estimates, not guarantees.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func saveKey() {
        GLMClient.shared.byoAPIKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKeyInput = ""
        keySaved = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            keySaved = false
        }
    }

    private func removeKey() {
        GLMClient.shared.byoAPIKey = nil
        keySaved = false
    }
}
