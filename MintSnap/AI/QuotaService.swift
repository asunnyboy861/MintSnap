import Foundation
import SwiftUI

@Observable
final class SettingsService {
    static let shared = SettingsService()

    var imageUploadAllowed: Bool {
        get { UserDefaults.standard.object(forKey: "imageUploadAllowed") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "imageUploadAllowed") }
    }

    var cloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cloudSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "cloudSyncEnabled") }
    }

    var weeklyPulseEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "weeklyPulseEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "weeklyPulseEnabled") }
    }
}

@Observable
final class QuotaService {
    static let shared = QuotaService()
    static let freeDailyOnDeviceScans = 5
    static let monthlyProCloudLimit = 30
    static let yearlyProCloudLimit = 60

    private(set) var onDeviceScansToday: Int
    private(set) var scansDate: String
    private(set) var cloudCredits: Int
    private(set) var proCloudUsed: Int
    private(set) var proCloudMonth: String

    init() {
        let defaults = UserDefaults.standard
        onDeviceScansToday = defaults.integer(forKey: "onDeviceScansToday")
        scansDate = defaults.string(forKey: "scansDate") ?? ""
        cloudCredits = defaults.integer(forKey: "cloudCredits")
        proCloudUsed = defaults.integer(forKey: "proCloudUsed")
        proCloudMonth = defaults.string(forKey: "proCloudMonth") ?? ""
        rolloverIfNeeded()
    }

    var isPro: Bool { StoreService.shared.isPro }
    var hasBYOKey: Bool { GLMClient.shared.hasBYOKey }

    var proCloudLimit: Int {
        StoreService.shared.activeProID == StoreService.proYearlyID
            ? Self.yearlyProCloudLimit
            : Self.monthlyProCloudLimit
    }

    var proCloudUsedThisMonth: Int {
        rolloverIfNeeded()
        return proCloudUsed
    }

    var freeScansRemaining: Int {
        max(0, Self.freeDailyOnDeviceScans - onDeviceScansToday)
    }

    var canOnDeviceScan: Bool {
        isPro || freeScansRemaining > 0
    }

    var cloudScanMode: CloudScanMode {
        if hasBYOKey { return .byoUnlimited }
        if cloudCredits > 0 { return .boost }
        if isPro && proCloudUsedThisMonth < proCloudLimit { return .proAllowance }
        return .none
    }

    func consumeOnDeviceScan() {
        rolloverIfNeeded()
        onDeviceScansToday += 1
        persist()
    }

    func consumeCloudCredit() {
        rolloverIfNeeded()
        switch cloudScanMode {
        case .boost:
            cloudCredits = max(0, cloudCredits - 1)
        case .proAllowance:
            proCloudUsed += 1
        case .byoUnlimited, .none:
            break
        }
        persist()
    }

    func addCloudCredits(_ count: Int) {
        cloudCredits += count
        persist()
    }

    private func rolloverIfNeeded() {
        let today = Self.dayKey()
        if scansDate != today {
            scansDate = today
            onDeviceScansToday = 0
        }
        let month = Self.monthKey()
        if proCloudMonth != month {
            proCloudMonth = month
            proCloudUsed = 0
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(onDeviceScansToday, forKey: "onDeviceScansToday")
        defaults.set(scansDate, forKey: "scansDate")
        defaults.set(cloudCredits, forKey: "cloudCredits")
        defaults.set(proCloudUsed, forKey: "proCloudUsed")
        defaults.set(proCloudMonth, forKey: "proCloudMonth")
    }

    static func dayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func monthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}

enum CloudScanMode {
    case byoUnlimited
    case boost
    case proAllowance
    case none
}
