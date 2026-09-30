import SwiftUI
import SwiftData

extension CGImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        UIImage(cgImage: self).jpegData(compressionQuality: compressionQuality)
    }
}

@Observable
final class ScanViewModel {
    enum ScanState {
        case idle
        case identifying
        case confirming(ScanSession)
        case failed(String)
    }

    struct ScanSession {
        let croppedImageData: Data?
        let localIdentity: CardIdentity
        let confidence: Float
        let candidates: [TCGdexService.TCgdexCard]
    }

    var state: ScanState = .idle
    var usedCloudFallback = false
    var cloudNotice: String?

    private let engine = ScanEngine()
    private let glm = GLMClient.shared
    private let quota = QuotaService.shared
    private let settings = SettingsService.shared

    var showSoftWall: Bool {
        !quota.isPro && quota.freeScansRemaining == 0
    }

    func handleCapturedImage(_ cgImage: CGImage) async {
        state = .identifying
        usedCloudFallback = false
        cloudNotice = nil

        guard let result = await engine.processStillImage(cgImage) else {
            state = .failed("Could not detect a card. Try better lighting.")
            return
        }

        var identity = localIdentity(from: result)
        var confidence = result.confidence

        if confidence < 0.85 {
            switch await cloudFallback(image: cgImage, hints: result.ocrLines) {
            case .success(let cloudIdentity):
                identity = cloudIdentity
                confidence = 0.95
                usedCloudFallback = true
                if !quota.hasBYOKey { quota.consumeCloudCredit() }
                cloudNotice = quota.hasBYOKey
                    ? "Identified with your own API key"
                    : "Identified with cloud AI (1 scan credit used)"
            case .failure(let error):
                cloudNotice = "Cloud fallback unavailable — verify results below"
                _ = error
            }
        }

        let candidates = await fetchCandidates(for: identity)
        let imageData = cgImage.jpegData(compressionQuality: 0.85)

        state = .confirming(ScanSession(
            croppedImageData: imageData,
            localIdentity: identity,
            confidence: confidence,
            candidates: candidates
        ))
    }

    private func cloudFallback(image: CGImage, hints: [String]) async -> Result<CardIdentity, Error> {
        guard quota.cloudScanMode != .none else {
            return .failure(GLMError.insufficientCredits)
        }
        guard settings.imageUploadAllowed else {
            return .failure(GLMError.proxyNotConfigured)
        }
        let base64 = image.jpegData(compressionQuality: 0.7)?.base64EncodedString() ?? ""
        guard !base64.isEmpty else { return .failure(GLMError.badResponse) }
        do {
            let identity = try await glm.identifyCard(base64JPEG: base64, ocrHints: hints)
            return .success(identity)
        } catch {
            return .failure(error)
        }
    }

    private func localIdentity(from result: CardScanResult) -> CardIdentity {
        var identity = CardIdentity()
        let nameLine = result.ocrLines.first { line in
            line.range(of: #"\d{1,4}\s*/\s*\d{1,4}"#, options: .regularExpression) == nil && line.count > 2
        }
        identity.cardName = nameLine ?? result.ocrLines.first ?? ""
        if let numberLine = result.ocrLines.first(where: { $0.range(of: #"\d{1,4}\s*/\s*\d{1,4}"#, options: .regularExpression) != nil }) {
            let cleaned = numberLine.replacingOccurrences(of: " ", with: "")
            identity.cardNumber = cleaned
        }
        identity.isGraded = result.isSlab
        identity.grader = result.grader
        identity.grade = result.grade
        identity.certNumber = result.certNumber
        return identity
    }

    private func fetchCandidates(for identity: CardIdentity) async -> [TCGdexService.TCgdexCard] {
        let query = identity.cardName.isEmpty ? identity.cardNumber : identity.cardName
        guard !query.isEmpty else { return [] }
        return (try? await TCGdexService.shared.search(query)) ?? []
    }

    func priceResult(for identity: CardIdentity) async -> PriceResult {
        let query = [identity.cardName, identity.cardNumber].filter { !$0.isEmpty }.joined(separator: " ")
        return await PriceChartingService.shared.fetchTieredPrice(query: query)
    }

    func reset() {
        state = .idle
        usedCloudFallback = false
        cloudNotice = nil
    }
}
