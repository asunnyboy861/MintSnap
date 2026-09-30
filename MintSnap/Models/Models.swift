import Foundation
import SwiftData

enum GradeTier: String, Codable, CaseIterable, Identifiable {
    case ungraded = "Ungraded"
    case g7 = "PSA 7"
    case g8 = "PSA 8"
    case g9 = "PSA 9"
    case g95 = "PSA 9.5"
    case psa10 = "PSA 10"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .ungraded: return "RAW"
        case .g7: return "7"
        case .g8: return "8"
        case .g9: return "9"
        case .g95: return "9.5"
        case .psa10: return "10"
        }
    }
}

enum HealthLabel: String, Codable {
    case high = "HIGH"
    case medium = "MED"
    case low = "LOW"
}

struct CardIdentity: Codable, Equatable {
    var cardName: String = ""
    var setName: String = ""
    var cardNumber: String = ""
    var isReverseHolo: Bool = false
    var isGraded: Bool = false
    var grader: String?
    var grade: String?
    var certNumber: String?
}

@Model
final class CardRecord {
    var name: String
    var setName: String
    var cardNumber: String
    var imageData: Data?
    var officialImageURL: String?
    var isReverseHolo: Bool
    var isGraded: Bool
    var grader: String?
    var grade: String?
    var certNumber: String?
    var certVerified: Bool
    var activeTier: String
    var currentPriceCents: Int
    var healthLabel: String
    var healthReason: String
    var priceSource: String
    var fetchedAt: Date
    var addedAt: Date

    init(identity: CardIdentity, imageData: Data?, officialImageURL: String?, tier: GradeTier, priceCents: Int, health: HealthLabel, reason: String, source: String) {
        self.name = identity.cardName
        self.setName = identity.setName
        self.cardNumber = identity.cardNumber
        self.imageData = imageData
        self.officialImageURL = officialImageURL
        self.isReverseHolo = identity.isReverseHolo
        self.isGraded = identity.isGraded
        self.grader = identity.grader
        self.grade = identity.grade
        self.certNumber = identity.certNumber
        self.certVerified = false
        self.activeTier = tier.rawValue
        self.currentPriceCents = priceCents
        self.healthLabel = health.rawValue
        self.healthReason = reason
        self.priceSource = source
        self.fetchedAt = Date()
        self.addedAt = Date()
    }
}

@Model
final class PriceSnapshot {
    var cardName: String
    var cardNumber: String
    var tier: String
    var valueCents: Int
    var source: String
    var salesCount: Int
    var fetchedAt: Date

    init(cardName: String, cardNumber: String, tier: String, valueCents: Int, source: String, salesCount: Int) {
        self.cardName = cardName
        self.cardNumber = cardNumber
        self.tier = tier
        self.valueCents = valueCents
        self.source = source
        self.salesCount = salesCount
        self.fetchedAt = Date()
    }
}

@Model
final class AlertRule {
    var cardName: String
    var cardNumber: String
    var thresholdCents: Int
    var above: Bool
    var isEnabled: Bool
    var createdAt: Date
    var lastTriggeredAt: Date?

    init(cardName: String, cardNumber: String, thresholdCents: Int, above: Bool) {
        self.cardName = cardName
        self.cardNumber = cardNumber
        self.thresholdCents = thresholdCents
        self.above = above
        self.isEnabled = true
        self.createdAt = Date()
    }
}
