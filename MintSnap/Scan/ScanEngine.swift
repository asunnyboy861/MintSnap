import Foundation
import Vision
import CoreImage
import ImageIO

struct CardScanResult {
    let croppedImage: CGImage
    let ocrLines: [String]
    let confidence: Float
    let isSlab: Bool
    let certNumber: String?
    let grader: String?
    let grade: String?
}

final class ScanEngine {
    private let ciContext = CIContext()

    func process(_ pixelBuffer: CVPixelBuffer) async -> CardScanResult? {
        let rectReq = VNDetectRectanglesRequest()
        rectReq.minimumConfidence = 0.5
        rectReq.minimumAspectRatio = 0.5
        rectReq.maximumAspectRatio = 0.9
        rectReq.maximumObservations = 1
        rectReq.quadratureTolerance = 25
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([rectReq])
        guard let rect = rectReq.results?.first else { return nil }

        guard let cropped = crop(pixelBuffer, normalizedRect: rect.boundingBox) else { return nil }

        let ocrReq = VNRecognizeTextRequest()
        ocrReq.recognitionLevel = .accurate
        ocrReq.recognitionLanguages = ["en-US", "ja-JP", "zh-Hans"]
        ocrReq.usesLanguageCorrection = false
        let ocrHandler = VNImageRequestHandler(cgImage: cropped)
        try? ocrHandler.perform([ocrReq])
        let candidates = ocrReq.results ?? []
        let lines = candidates.compactMap { $0.topCandidates(1).first?.string }
        let ocrConf = candidates.first?.topCandidates(1).first?.confidence ?? 0.3

        let galleryScore = await CardGallery.shared.bestMatchScore(cropped)
        let slab = detectSlab(lines)

        return CardScanResult(
            croppedImage: cropped,
            ocrLines: lines,
            confidence: max(similarity(galleryScore), Float(ocrConf)),
            isSlab: slab.isSlab,
            certNumber: slab.certNumber,
            grader: slab.grader,
            grade: slab.grade
        )
    }

    func processStillImage(_ image: CGImage) async -> CardScanResult? {
        let ocrReq = VNRecognizeTextRequest()
        ocrReq.recognitionLevel = .accurate
        ocrReq.recognitionLanguages = ["en-US", "ja-JP", "zh-Hans"]
        ocrReq.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image)
        try? handler.perform([ocrReq])
        let candidates = ocrReq.results ?? []
        let lines = candidates.compactMap { $0.topCandidates(1).first?.string }
        let ocrConf = candidates.first?.topCandidates(1).first?.confidence ?? 0.5
        let slab = detectSlab(lines)
        return CardScanResult(
            croppedImage: image,
            ocrLines: lines,
            confidence: max(0.9, Float(ocrConf)),
            isSlab: slab.isSlab,
            certNumber: slab.certNumber,
            grader: slab.grader,
            grade: slab.grade
        )
    }

    private struct SlabInfo {
        let isSlab: Bool
        let certNumber: String?
        let grader: String?
        let grade: String?
    }

    private func detectSlab(_ lines: [String]) -> SlabInfo {
        let graders = ["PSA", "BGS", "BGSG", "SGC", "CGC", "HGA", "ACE"]
        var grader: String?
        var grade: String?
        var cert: String?
        for line in lines {
            let upper = line.uppercased()
            if grader == nil {
                for g in graders where upper.contains(g) {
                    grader = g == "BGSG" ? "BGS" : g
                    break
                }
            }
            if grade == nil {
                let gradePatterns = [#"(?:GEM\s*MT|GEM\s*MINT)\s*(\d{1,2}(?:\.\d)?)"#, #"(?:MINT|NM(?:\s*MT)?)\s*(\d{1,2}(?:\.\d)?)"#, #"\b(10|9\.5|9|8\.5|8|7\.5|7)\b"#]
                for p in gradePatterns {
                    if let r = upper.range(of: p, options: .regularExpression) {
                        let digits = upper[r].filter { $0.isNumber || $0 == "." }
                        if !digits.isEmpty { grade = digits; break }
                    }
                }
            }
            if cert == nil, let r = line.range(of: #"\b\d{8,10}\b"#, options: .regularExpression) {
                cert = String(line[r])
            }
        }
        return SlabInfo(isSlab: grader != nil, certNumber: cert, grader: grader, grade: grade)
    }

    private func similarity(_ galleryScore: Float) -> Float {
        galleryScore
    }

    private func crop(_ pb: CVPixelBuffer, normalizedRect r: CGRect) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pb)
        let width = ciImage.extent.width
        let height = ciImage.extent.height
        let inset = CGRect(
            x: max(0, (r.origin.x - 0.01)) * width,
            y: max(0, (1 - r.origin.y - r.height - 0.01)) * height,
            width: min(1, r.width + 0.02) * width,
            height: min(1, r.height + 0.02) * height
        )
        guard let cropped = ciContext.createCGImage(ciImage, from: inset) else { return nil }
        return cropped
    }
}

final class CardGallery {
    static let shared = CardGallery()
    private var index: [(cardId: String, feature: VNFeaturePrintObservation)] = []

    func bestMatchScore(_ image: CGImage) async -> Float {
        guard !index.isEmpty else { return 0 }
        let req = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try? handler.perform([req])
        guard let query = req.results?.first as? VNFeaturePrintObservation else { return 0 }
        var best: Float = 0
        for item in index {
            var d: Float = 0
            try? query.computeDistance(&d, to: item.feature)
            let score = max(0, 1 - d / 20.0)
            best = max(best, score)
        }
        return best
    }

    func addToGallery(cardId: String, image: CGImage) {
        let req = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try? handler.perform([req])
        if let feature = req.results?.first as? VNFeaturePrintObservation {
            index.append((cardId, feature))
        }
    }
}
