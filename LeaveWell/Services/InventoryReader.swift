import Foundation
import PDFKit
import UIKit
import ImageIO
import Vision

struct InventoryPage: Sendable {
    let preview: Data
    let suggestions: [String]
}

enum InventoryReadError: LocalizedError {
    case unavailable
    var errorDescription: String? { L("This inventory page could not be opened. Check the file and try again.") }
}

actor InventoryReader {
    func pageCount(_ url: URL) throws -> Int {
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url), !pdf.isLocked, pdf.pageCount > 0 else { throw InventoryReadError.unavailable }
            return pdf.pageCount
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw InventoryReadError.unavailable
        }
        return 1
    }

    func read(_ url: URL, page number: Int, suggest: Bool) throws -> InventoryPage {
        try Task.checkCancellation()
        let image: UIImage
        let text: String
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url), !pdf.isLocked, let page = pdf.page(at: number - 1) else {
                throw InventoryReadError.unavailable
            }
            let bounds = page.bounds(for: .cropBox)
            let scale = 1800 / max(bounds.width, bounds.height, 1)
            image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .cropBox)
            text = suggest ? (page.string ?? "") : ""
        } else {
            let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                           kCGImageSourceCreateThumbnailWithTransform: true,
                           kCGImageSourceThumbnailMaxPixelSize: 1800] as CFDictionary
            guard number == 1, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { throw InventoryReadError.unavailable }
            image = UIImage(cgImage: thumbnail)
            text = ""
        }
        guard let preview = image.jpegData(compressionQuality: 0.86) else { throw InventoryReadError.unavailable }
        var lines = text.components(separatedBy: .newlines)
        if suggest, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let pixels = image.cgImage {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            if let language = Locale.current.language.languageCode?.identifier,
               let supported = try? request.supportedRecognitionLanguages(),
               let match = supported.first(where: { $0 == language || $0.hasPrefix(language + "-") }) {
                request.recognitionLanguages = [match]
            }
            if (try? VNImageRequestHandler(cgImage: pixels).perform([request])) != nil {
                lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            }
        }
        try Task.checkCancellation()
        var seen = Set<String>()
        let suggestions = lines.lazy.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000)) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return InventoryPage(preview: preview, suggestions: Array(suggestions.prefix(60)))
    }
}

extension CaseStore {
    func importInventory(_ url: URL, caseID: UUID, reader: InventoryReader) async throws -> UUID {
        let original = try await vault.importFile(at: url, origin: .imported, capturedAt: nil)
        do {
            let verified = try await vault.verifiedURL(for: original)
            _ = try await reader.pageCount(verified)
            try Task.checkCancellation()
            guard let record = record(caseID) else { throw VaultError.missingFile }
            if let duplicate = record.evidence.first(where: { $0.kind == .document && $0.original?.sha256 == original.sha256 }) {
                try await vault.remove(original)
                return duplicate.id
            }
            let item = Evidence(kind: .document, label: original.originalName, original: original, contributor: record.tenant)
            try update(caseID, action: "Inventory imported") { $0.evidence.append(item) }
            return item.id
        } catch {
            try? await vault.remove(original)
            throw error
        }
    }

    func practiceInventory() async throws -> UUID {
        if let sample = archive.cases.first(where: { $0.isPracticeRecord == true }) { return sample.id }
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let pdf = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            let lines = [L("Fictional practice inventory"), L("Kitchen"), L("Sink: light scratches beside the drain."),
                         L("Worktop: small mark near the window."), L("Cupboard: all handles present.")]
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(in: CGRect(x: 48, y: 52 + index * 58, width: 499, height: 52),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: index == 0 ? 24 : 17)])
            }
        }
        let name = L("Fictional practice inventory")
        let original = try await vault.store(pdf, name: name + ".pdf", origin: .imported, capturedAt: nil)
        do {
            if let sample = archive.cases.first(where: { $0.isPracticeRecord == true }) {
                try await vault.remove(original)
                return sample.id
            }
            var sample = MoveCase()
            sample.isPracticeRecord = true
            sample.nickname = name
            sample.address = L("Fictional test property")
            sample.rooms = [Room(name: L("Kitchen"), category: "Kitchen")]
            let item = Evidence(kind: .document, label: name, original: original)
            sample.evidence = [item]
            sample.checkout = CheckoutSession()
            try add(sample)
            return sample.id
        } catch {
            try? await vault.remove(original)
            throw error
        }
    }
}
