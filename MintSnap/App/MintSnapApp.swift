import SwiftUI
import SwiftData

@main
struct MintSnapApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([CardRecord.self, PriceSnapshot.self, AlertRule.self])
        if SettingsService.shared.cloudSyncEnabled {
            do {
                container = try ModelContainer(for: schema, configurations: ModelConfiguration(cloudKitDatabase: .automatic))
            } catch {
                container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: false))
            }
        } else {
            container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: false))
        }
        AlertEngine.registerTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .environment(StoreService.shared)
                .environment(QuotaService.shared)
                .environment(SettingsService.shared)
                .tint(Color.mintAccent)
                .preferredColorScheme(.dark)
                .task {
                    await AlertEngine.shared.scheduleAndRefresh()
                }
        }
    }
}

extension Color {
    static let mintAccent = Color(red: 0, green: 0.84, blue: 0.56)
    static let cardGold = Color(red: 0.85, green: 0.72, blue: 0.42)
}
