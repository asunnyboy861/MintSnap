import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum InsightsService {
    static func pulseSummary(for stats: CollectionStats) async -> String {
        if #available(iOS 26, *) {
            #if canImport(FoundationModels)
            if let generated = try? await foundationSummary(for: stats) {
                return generated
            }
            #endif
        }
        return templateSummary(for: stats)
    }

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private static func foundationSummary(for stats: CollectionStats) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        You are a trading-card collection assistant. Write a short, friendly weekly pulse (max 3 sentences, US card-community tone, number-first):
        Cards: \(stats.cardCount), total value \(BinderView.dollarString(cents: stats.totalValueCents)), graded: \(stats.gradedCount), top card: \(stats.topCardName) at \(BinderView.dollarString(cents: stats.topCardCents)).
        Mention the top card and one grading or diversification tip if relevant.
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }
    #endif

    static func templateSummary(for stats: CollectionStats) -> String {
        guard stats.cardCount > 0 else {
            return "Your binder is empty. Scan a card to start tracking value."
        }
        let gradedShare = stats.cardCount > 0 ? Int((Double(stats.gradedCount) / Double(stats.cardCount)) * 100) : 0
        var lines = [
            "Your collection is worth \(BinderView.dollarString(cents: stats.totalValueCents)) across \(stats.cardCount) cards.",
            "Top card: \(stats.topCardName) at \(BinderView.dollarString(cents: stats.topCardCents))."
        ]
        if gradedShare < 50 {
            lines.append("Only \(gradedShare)% of your cards are graded — high-value raw cards may be grading candidates. Check the ROI calculator.")
        } else {
            lines.append("\(gradedShare)% of your cards are graded — solid slab coverage for resale.")
        }
        return lines.joined(separator: "\n")
    }
}
