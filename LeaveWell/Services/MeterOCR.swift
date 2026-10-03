import Vision
import Foundation

actor MeterOCR {
    /// Suggestions remain drafts until a person selects, checks and saves a reading.
    func candidates(from url: URL) throws -> [String] {
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(url: url).perform([request])
        let values = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let regex = try NSRegularExpression(pattern: #"\b[0-9]{3,}(?:[.,][0-9]+)?\b"#)
        var found: [String] = []
        for value in values {
            for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)) {
                if let range = Range(match.range, in: value) {
                    let candidate = String(value[range]); if !found.contains(candidate) { found.append(candidate) }
                }
            }
        }
        return found
    }
}
