import Foundation
import BackgroundTasks
import UserNotifications
import SwiftData

final class AlertEngine {
    static let shared = AlertEngine()
    static let pollIdentifier = "com.zzoutuo.MintSnap.pricepoll"
    static let weeklyPulseIdentifier = "com.zzoutuo.MintSnap.weeklypulse"

    static func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.pollIdentifier, using: nil) { task in
            Self.shared.handlePoll(task: task)
        }
    }

    func scheduleAndRefresh() async {
        schedulePoll()
        await requestNotificationPermission()
        await refreshWeeklyPulse()
    }

    private func schedulePoll() {
        let request = BGAppRefreshTaskRequest(identifier: Self.pollIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 12)
        try? BGTaskScheduler.shared.submit(request)
    }

    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func cancelWeeklyPulse() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.weeklyPulseIdentifier])
    }

    func scheduleTrialEndNudge() {
        Task { await requestNotificationPermission() }
        let content = UNMutableNotificationContent()
        content.title = "MintSnap Pro Trial"
        content.body = "Your 7-day free trial ends in 2 days. Your binder keeps tracking — decide if Pro stays."
        content.sound = .default
        var components = DateComponents()
        components.day = 5
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "com.zzoutuo.MintSnap.trialnudge", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func handlePoll(task: BGTask) {
        task.expirationHandler = {}
        Task {
            await pollAlerts()
            await refreshWeeklyPulse()
            schedulePoll()
            task.setTaskCompleted(success: true)
        }
    }

    private func pollAlerts() async {
        guard let container = try? ModelContainer(
            for: CardRecord.self, PriceSnapshot.self, AlertRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AlertRule>(predicate: #Predicate { $0.isEnabled })
        guard let rules = try? context.fetch(descriptor), !rules.isEmpty else { return }

        for rule in rules {
            let query = [rule.cardName, rule.cardNumber].filter { !$0.isEmpty }.joined(separator: " ")
            guard !query.isEmpty else { continue }
            let result = await PriceChartingService.shared.fetchTieredPrice(query: query)
            guard let price = result.tiered?.ungraded, price > 0 else { continue }
            let crossed = rule.above ? price >= rule.thresholdCents : price <= rule.thresholdCents
            if crossed {
                await fireAlert(rule: rule, priceCents: price)
                rule.lastTriggeredAt = Date()
            }
        }
        try? context.save()
    }

    private func fireAlert(rule: AlertRule, priceCents: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Price Alert"
        content.body = "\(rule.cardName) is now \(BinderView.dollarString(cents: priceCents)) — \(rule.above ? "above" : "below") your \(BinderView.dollarString(cents: rule.thresholdCents)) threshold."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "alert-\(rule.cardNumber)-\(UUID().uuidString.prefix(6))",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func refreshWeeklyPulse() async {
        guard SettingsService.shared.weeklyPulseEnabled else { return }
        guard let container = try? ModelContainer(
            for: CardRecord.self, PriceSnapshot.self, AlertRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else { return }
        let context = ModelContext(container)
        guard let records = try? context.fetch(FetchDescriptor<CardRecord>()), !records.isEmpty else { return }

        let body = Self.weeklyPulseText(records: records)
        let content = UNMutableNotificationContent()
        content.title = "Weekly Collection Pulse"
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1
        components.hour = 20
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.weeklyPulseIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func weeklyPulseText(records: [CardRecord]) -> String {
        let total = records.reduce(0) { $0 + $1.currentPriceCents }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let olderRecords = records.filter { $0.addedAt < cutoff }
        guard !olderRecords.isEmpty,
              let oldestPerCard = Dictionary(grouping: olderRecords, by: { $0.cardNumber })
                  .compactMapValues({ $0.min(by: { $0.fetchedAt < $1.fetchedAt }) })
                  .values
                  .max(by: { $0.fetchedAt < $1.fetchedAt })
        else {
            return "Your collection is worth \(BinderView.dollarString(cents: total)) across \(records.count) cards."
        }
        let current = records
            .first { $0.cardNumber == oldestPerCard.cardNumber }?
            .currentPriceCents ?? oldestPerCard.currentPriceCents
        let deltaCents = current - oldestPerCard.currentPriceCents
        let deltaPct = oldestPerCard.currentPriceCents > 0
            ? Int((Double(deltaCents) / Double(oldestPerCard.currentPriceCents)) * 100)
            : 0
        let direction = deltaCents >= 0 ? "gained" : "lost"
        let sign = deltaCents >= 0 ? "+" : "-"
        return "Your collection \(direction) \(sign)\(BinderView.dollarString(cents: abs(deltaCents))) this week. Top mover: \(oldestPerCard.name) \(sign)\(abs(deltaPct))%"
    }
}
