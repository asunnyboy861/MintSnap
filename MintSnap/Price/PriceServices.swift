import Foundation

struct TieredPrice {
    var ungraded: Int?
    var grade7: Int?
    var grade8: Int?
    var grade9: Int?
    var grade95: Int?
    var psa10: Int?

    func value(for tier: GradeTier) -> Int? {
        switch tier {
        case .ungraded: return ungraded
        case .g7: return grade7
        case .g8: return grade8
        case .g9: return grade9
        case .g95: return grade95
        case .psa10: return psa10
        }
    }

    var availableTiers: [GradeTier] {
        GradeTier.allCases.filter { value(for: $0) != nil }
    }
}

struct PriceResult {
    let tiered: TieredPrice?
    let source: String
    let health: PriceHealth
    let officialImageURL: String?
    let salesCount: Int
}

struct PriceHealth: Equatable {
    let label: HealthLabel
    let reason: String
}

enum PriceHealthEngine {
    static func evaluate(salesCents: [Int]) -> PriceHealth {
        guard salesCents.count >= 3 else {
            return PriceHealth(label: .low, reason: "Too few sales (\(salesCents.count)) in last 90 days")
        }
        let sorted = salesCents.sorted()
        let median = sorted[sorted.count / 2]
        let deviations = sorted.map { abs($0 - median) }.sorted()
        let mad = max(deviations[deviations.count / 2], 1)
        let cleaned = sorted.filter { Double(abs($0 - median)) <= 3 * 1.4826 * Double(mad) }
        guard cleaned.count >= 3 else {
            return PriceHealth(label: .low, reason: "Extreme outliers — sales disagree wildly")
        }
        let spread = Double(cleaned.max()! - cleaned.min()!) / Double(max(median, 1))
        if spread < 0.15 {
            return PriceHealth(label: .high, reason: "Consistent sales across sources")
        }
        if spread < 0.40 {
            return PriceHealth(label: .medium, reason: "Moderate variance (\(Int(spread * 100))%)")
        }
        return PriceHealth(label: .low, reason: "High variance (\(Int(spread * 100))%) — treat as range")
    }
}

enum CrossGraderMatrix {
    static let toPSA10: [String: Double] = [
        "PSA": 1.0,
        "BGS": 0.95,
        "SGC": 0.75,
        "CGC": 0.85,
        "HGA": 0.85
    ]

    static func estimatePSA10(fromGrader grader: String, grade: String, psa10Price: Int?) -> Int? {
        guard let psa10Price else { return nil }
        guard let factor = toPSA10[grader.uppercased()] else { return nil }
        let gradeValue = Double(grade) ?? 10
        let gradeFactor = gradeValue / 10.0
        return Int((Double(psa10Price) * factor * gradeFactor).rounded())
    }
}

struct GradeROICalculator {
    let rawPriceCents: Int
    let gradingFeeCents: Int
    let shippingCents: Int
    let expectedTierPriceCents: Int

    var totalCostCents: Int {
        gradingFeeCents + shippingCents
    }

    var netProfitCents: Int {
        expectedTierPriceCents - totalCostCents
    }

    var isWorthIt: Bool {
        netProfitCents >= 5000
    }

    var verdict: String {
        isWorthIt ? "Worth it" : "Skip it"
    }
}

final class PriceChartingService {
    static let shared = PriceChartingService()

    private var token: String? {
        guard let url = Bundle.main.url(forResource: "PriceChartingSecret", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    var isConfigured: Bool { token != nil }

    func fetchTieredPrice(query: String) async -> PriceResult {
        guard let token else {
            return await tcgdexFallback(query: query)
        }
        var components = URLComponents(string: "https://www.pricecharting.com/api/product")
        components?.queryItems = [
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "q", value: query)
        ]
        guard let url = components?.url else {
            return await tcgdexFallback(query: query)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  json["status"] == "success" else {
                return await tcgdexFallback(query: query)
            }
            let tiered = TieredPrice(
                ungraded: json["loose-price"].flatMap(cents),
                grade7: json["grade7-price"].flatMap(cents),
                grade8: json["grade8-price"].flatMap(cents),
                grade9: json["grade9-price"].flatMap(cents),
                grade95: json["grade9.5-price"].flatMap(cents),
                psa10: json["grade10-price"].flatMap(cents)
            )
            return PriceResult(
                tiered: tiered,
                source: "PriceCharting",
                health: PriceHealthEngine.evaluate(salesCents: tiered.availableTiers.compactMap { tiered.value(for: $0) }),
                officialImageURL: nil,
                salesCount: tiered.availableTiers.count
            )
        } catch {
            return await tcgdexFallback(query: query)
        }
    }

    private func cents(_ raw: String) -> Int? {
        Int(raw)
    }

    private func tcgdexFallback(query: String) async -> PriceResult {
        let cards = try? await TCGdexService.shared.search(query)
        guard let first = cards?.first else {
            return PriceResult(
                tiered: nil,
                source: "None",
                health: PriceHealth(label: .low, reason: "No price data found for this card"),
                officialImageURL: nil,
                salesCount: 0
            )
        }
        let detail = try? await TCGdexService.shared.card(id: first.id)
        var ungraded: Int?
        if let prices = detail?.prices {
            ungraded = prices.tcgplayer?.normal?.lowMid.map { $0 * 100 }
                ?? prices.cardmarket?.averageSellPrice.map { Int($0 * 100) }
        }
        let tiered = TieredPrice(ungraded: ungraded, grade7: nil, grade8: nil, grade9: nil, grade95: nil, psa10: nil)
        let health = ungraded == nil
            ? PriceHealth(label: .low, reason: "No sales data available — sample too small")
            : PriceHealth(label: .low, reason: "Single-source estimate (TCGdex) — verify before buying")
        return PriceResult(
            tiered: tiered,
            source: "TCGdex",
            health: health,
            officialImageURL: TCGdexService.shared.imageURL(from: detail?.image),
            salesCount: 1
        )
    }
}

final class TCGdexService {
    static let shared = TCGdexService()
    private let base = "https://api.tcgdex.net/v2/en"

    struct TCgdexCard: Codable {
        let id: String
        let name: String
        let image: String?
        let localId: String?
        let set: TCgdexSetRef?
    }

    struct TCgdexSetRef: Codable {
        let id: String?
        let name: String?
    }

    struct TCgdexCardDetail: Codable {
        let id: String
        let name: String
        let image: String?
        let set: TCgdexSetRef?
        let prices: TCgdexPrices?
    }

    struct TCgdexPrices: Codable {
        let tcgplayer: TCgdexTCGPlayer?
        let cardmarket: TCgdexCardmarket?
    }

    struct TCgdexTCGPlayer: Codable {
        let normal: TCgdexPricePoints?
        let reverseHolo: TCgdexPricePoints?
        let holo: TCgdexPricePoints?
    }

    struct TCgdexPricePoints: Codable {
        let low: Int?
        let mid: Int?
        let high: Int?
        let market: Int?
        let lowMid: Int?
    }

    struct TCgdexCardmarket: Codable {
        let averageSellPrice: Double?
        let lowPrice: Double?
        let trendPrice: Double?
    }

    func search(_ text: String) async throws -> [TCgdexCard] {
        guard var components = URLComponents(string: "\(base)/cards") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "name", value: text)]
        guard let url = components.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([TCgdexCard].self, from: data)
    }

    func card(id: String) async throws -> TCgdexCardDetail {
        guard let url = URL(string: "\(base)/cards/\(id)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(TCgdexCardDetail.self, from: data)
    }

    func imageURL(from path: String?) -> String? {
        guard let path else { return nil }
        return "https://assets.tcgdex.net/en/\(path)/high.png"
    }
}
