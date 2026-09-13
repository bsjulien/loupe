import Vision
import AppKit

struct RecognizedTextRegion {
    let text: String
    /// Normalized (0-1), bottom-left origin, per Vision's convention.
    let boundingBox: CGRect
}

final class OCRManager {
    static let shared = OCRManager()
    private init() {}

    func recognizeText(in image: CGImage) async throws -> [RecognizedTextRegion] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let regions = observations.compactMap { obs -> RecognizedTextRegion? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return RecognizedTextRegion(text: candidate.string, boundingBox: obs.boundingBox)
                }
                continuation.resume(returning: regions)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func copyAllText(_ regions: [RecognizedTextRegion]) {
        let text = regions.map(\.text).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func text(in regions: [RecognizedTextRegion], within normalizedRect: CGRect) -> String {
        regions
            .filter { $0.boundingBox.intersects(normalizedRect) }
            .map(\.text)
            .joined(separator: "\n")
    }
}
