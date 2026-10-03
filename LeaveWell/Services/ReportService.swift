import UIKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers

struct ReportOptions {
    var includeContactDetails = false
    var includeDepositDetails = false
    var declarationAccepted = false
}

@MainActor
protocol ReportGenerating {
    func generate(record: MoveCase, options: ReportOptions, vault: EvidenceVault) async throws -> URL
}

@MainActor
final class ReportService: ReportGenerating {
    private let width: CGFloat = 595.2
    private let height: CGFloat = 841.8
    private let margin: CGFloat = 46
    private let ink = UIColor(red: 0.10, green: 0.20, blue: 0.19, alpha: 1)
    private enum Block {
        case title(String), text(String), image(URL, String), pdf(URL, Int), gap
    }
    private struct SectionRecord {
        let title: String
        let blocks: [Block]
    }
    private struct Placed {
        let block: Block
        let rect: CGRect
    }
    func generate(record: MoveCase, options: ReportOptions, vault: EvidenceVault) async throws -> URL {
        let included = record.evidence.filter(\.includedInReport)
        var files: [UUID: URL] = [:]
        for item in included {
            if let original = item.original {
                let url = try await vault.verifiedURL(for: original)
                if Self.isImage(url) {
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                          CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2000] as CFDictionary) != nil else { throw ReportError.unreadableOriginal }
                } else if url.pathExtension.lowercased() == "pdf" {
                    guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else { throw ReportError.unreadableOriginal }
                }
                files[item.id] = url
            }
        }
        let generatedAt = Date()
        let sections = buildSections(record: record, evidence: included, files: files, options: options, generatedAt: generatedAt)
        let layouts = sections.map { layout($0.blocks) }
        var pageNumber = 3 // cover, contents; contents may itself grow below
        var contents = sections.enumerated().map { index, section -> String in
            defer { pageNumber += layouts[index].count }
            return section.title + "  ·  " + L("Page") + " \(pageNumber)"
        }
        var contentsPages = layout([.title(L("Contents"))] + contents.map { .text($0) })
        // Contents page count depends on text height; recompute page references once with its actual size.
        pageNumber = 2 + contentsPages.count
        contents = sections.enumerated().map { index, section in
            defer { pageNumber += layouts[index].count }
            return section.title + "  ·  " + L("Page") + " \(pageNumber)"
        }
        contentsPages = layout([.title(L("Contents"))] + contents.map { .text($0) })
        let pages = contentsPages + layouts.flatMap { $0 }
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: L("Move-Out Condition Record"), kCGPDFContextCreator as String: "LeaveWell"]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: width, height: height), format: format)
        let directory = try ExportWorkspace.make(); let url = directory.appendingPathComponent("LeaveWell-\(record.id.uuidString).pdf")
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            drawCover(record, generatedAt: generatedAt)
            footer(record.reference, page: 1, total: pages.count + 1)
            for (index, page) in pages.enumerated() {
                context.beginPage()
                for placed in page { draw(placed, context: context.cgContext) }
                footer(record.reference, page: index + 2, total: pages.count + 1)
            }
        }
        try EvidenceVault.protect(url)
        return url
    }
    private static func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }
    private func buildSections(record: MoveCase, evidence: [Evidence], files: [UUID: URL], options: ReportOptions, generatedAt: Date) -> [SectionRecord] {
        var summary: [Block] = [.title(L("Move-out summary")), .text(record.address),
            .text(L("Tenant") + ": " + record.tenant), .text(L("Move-out date") + ": " + record.moveDate.formatted(date: .long, time: .omitted)),
            .text(L("Tenancy end date") + ": " + record.tenancyEndDate.formatted(date: .long, time: .omitted)),
            .text(L("Property type") + ": " + L(record.propertyType)),
            .text(L("Region") + ": " + L(Jurisdictions.supported.first { $0.id == record.jurisdictionCode }?.title ?? "Other region"))]
        if let checkout = record.checkoutAt { summary.append(.text(L("Checkout appointment") + ": " + stamp(checkout))) }
        if options.includeContactDetails {
            summary += [.text(L("Landlord / agent name") + ": " + record.agentName), .text(L("Landlord / agent contact") + ": " + record.agentContact)]
        }
        if options.includeDepositDetails { summary += [.text(L("Deposit amount") + ": " + record.depositAmount), .text(L("Deposit scheme") + ": " + record.depositScheme)] }
        let documented = record.rooms.filter { room in evidence.contains { $0.roomID == room.id } }.count
        summary += [.title(L("Completion summary")), .text("\(documented) " + L("rooms with evidence")),
            .text("\(evidence.filter { $0.kind == .photo }.count) " + L("photographs")),
            .text("\(evidence.filter { $0.kind == .video }.count) " + L("videos")),
            .text("\(record.meters.count) " + L("meter readings")), .text("\(record.accessItems.count) " + L("access item records")),
            .text("\(evidence.filter { $0.kind == .document }.count) " + L("supporting documents")),
            .text(L("Video and audio are indexed in this report. Share original media separately using data export.")),
            .text(L("Checklist review is recorded by the user and does not certify the property condition."))]
        var result = [SectionRecord(title: L("Move-out summary"), blocks: summary)]
        var roomIndex: [Block] = [.title(L("Room index"))]
        for room in record.rooms {
            let count = evidence.filter { $0.roomID == room.id }.count
            roomIndex.append(.text(room.name + " · " + "\(count) " + L("evidence items") + " · " + room.progress.formatted(.percent.precision(.fractionLength(0))) + " " + L("reviewed")))
        }
        result.append(SectionRecord(title: L("Room index"), blocks: roomIndex))
        for room in record.rooms {
            var blocks: [Block] = [.title(room.name)]
            if !room.notes.isEmpty { blocks.append(.text(room.notes)) }
            let items = evidence.filter { $0.roomID == room.id }
            if items.isEmpty { blocks.append(.text(L("No evidence included for this room."))) }
            for item in items { blocks += evidenceBlocks(item, url: files[item.id]) }
            result.append(SectionRecord(title: room.name, blocks: blocks))
        }
        var meters: [Block] = [.title(L("Meter readings"))]
        if record.meters.isEmpty { meters.append(.text(L("No meter readings recorded."))) }
        for meter in record.meters {
            meters += [.title(L(meter.type) + " · " + meter.reading), .text(stamp(meter.recordedAt)), .text(L("Serial number") + ": " + meter.serialNumber), .text(meter.notes), .text(meter.confirmedByUser ? L("Reading confirmed by the user.") : L("Reading not confirmed."))]
            if let id = meter.evidenceID, let item = evidence.first(where: { $0.id == id }) { meters += evidenceBlocks(item, url: files[id]) }
        }
        result.append(SectionRecord(title: L("Meter readings"), blocks: meters))
        var keys: [Block] = [.title(L("Keys & access"))]
        if record.accessItems.isEmpty { keys.append(.text(L("No access items recorded."))) }
        for item in record.accessItems {
            keys += [.title("\(item.quantity) " + L(item.type)), .text(L("Handover method") + ": " + item.method), .text(L("Recipient") + ": " + item.recipient), .text(item.handedOverAt.map(stamp) ?? L("Handover not recorded")), .text(item.notes)]
            if let id = item.evidenceID, let evidence = evidence.first(where: { $0.id == id }) { keys += evidenceBlocks(evidence, url: files[id]) }
        }
        result.append(SectionRecord(title: L("Keys & access"), blocks: keys))
        var docs: [Block] = [.title(L("Supporting documents and other records"))]
        for item in evidence.filter({ $0.roomID == nil }) { docs += evidenceBlocks(item, url: files[item.id]) }
        result.append(SectionRecord(title: L("Supporting documents and other records"), blocks: docs))
        let timeline = evidence.sorted { $0.createdAt < $1.createdAt }.map { item in
            Block.text(stamp(item.createdAt) + " · " + item.label + " · " + item.reference)
        }
        result.append(SectionRecord(title: L("Evidence timeline"), blocks: [.title(L("Evidence timeline")), .text(L("Timeline includes records selected for this report."))] + timeline))
        result.append(SectionRecord(title: L("Declaration and record information"), blocks: [
            .title(L("Declaration")),
            .text(options.declarationAccepted ? L("To the best of my knowledge, this record reflects the property and information I documented at the stated dates and times.") : L("No declaration has been made by the user.")),
            .title(L("Record information")), .text(record.reference), .text(L("Report created") + ": " + stamp(generatedAt)),
            .text(L("Timestamps are recorded from the device clock. Imported items may have no known capture time. SHA-256 hashes identify stored file bytes; they do not certify when, where or by whom evidence was captured.")),
            .text(L("This report organises information supplied by the user. It does not determine legal liability, fair wear and tear, or the outcome of a deposit dispute."))]))
        return result
    }
    private func evidenceBlocks(_ item: Evidence, url: URL?) -> [Block] {
        var blocks: [Block] = [.gap, .title(item.label), .text(item.reference), .text(item.condition.title),
            .text(L("Created") + ": " + stamp(item.createdAt)), .text(L("Updated") + ": " + stamp(item.updatedAt))]
        if !item.notes.isEmpty { blocks.append(.text(L("User note") + ": " + item.notes)) }
        if !item.contributor.isEmpty { blocks.append(.text(L("Added by") + ": " + item.contributor)) }
        if !item.transcript.isEmpty { blocks += [.text(L("Machine transcription; review against the recording.")), .text(item.transcript)] }
        if let original = item.original {
            blocks += [.text(L("Captured") + ": " + (original.capturedAt.map(stamp) ?? L("Unknown"))), .text(L("Original file") + ": " + original.originalName), .text(L("SHA-256") + ": " + original.sha256)]
            if let imported = original.importedAt { blocks.append(.text(L("Imported") + ": " + stamp(imported))) }
            if let url {
                if Self.isImage(url) { blocks.append(.image(url, item.label + " · " + item.reference)) }
                else if url.pathExtension.lowercased() == "pdf", let document = PDFDocument(url: url) {
                    for index in 0..<document.pageCount { blocks.append(.pdf(url, index)) }
                }
            }
        }
        return blocks
    }
    private func stamp(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .long
        return formatter.string(from: date)
    }
    private func attributes(title: Bool = false) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 4; paragraph.baseWritingDirection = .natural
        return [.font: UIFont.systemFont(ofSize: title ? 19 : 11, weight: title ? .semibold : .regular), .foregroundColor: ink, .paragraphStyle: paragraph]
    }
    private func textHeight(_ text: String, title: Bool) -> CGFloat {
        ceil((text as NSString).boundingRect(with: CGSize(width: width - margin * 2, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes(title: title), context: nil).height) + 8
    }
    private func layout(_ blocks: [Block]) -> [[Placed]] {
        var pages: [[Placed]] = [[]]; var y: CGFloat = margin
        let bottom = height - 70
        func newPage() { if !pages[pages.count - 1].isEmpty { pages.append([]) }; y = margin }
        func place(_ block: Block, height h: CGFloat) {
            if y + h > bottom { newPage() }
            pages[pages.count - 1].append(Placed(block: block, rect: CGRect(x: margin, y: y, width: width - margin * 2, height: h)))
            y += h + 12
        }
        for block in blocks {
            switch block {
            case .title(let text), .text(let text):
                guard !text.isEmpty else { continue }
                let title: Bool; if case .title = block { title = true } else { title = false }
                // Split arbitrarily long notes at grapheme boundaries so no text is clipped.
                var remainder = text
                while !remainder.isEmpty {
                    let fullHeight = textHeight(remainder, title: title)
                    if fullHeight <= bottom - margin {
                        place(title ? .title(remainder) : .text(remainder), height: fullHeight); break
                    }
                    let chars = Array(remainder); var low = 1; var high = chars.count
                    while low < high {
                        let mid = (low + high + 1) / 2
                        if textHeight(String(chars.prefix(mid)), title: title) <= bottom - margin { low = mid } else { high = mid - 1 }
                    }
                    let part = String(chars.prefix(low)); place(title ? .title(part) : .text(part), height: textHeight(part, title: title))
                    remainder = String(chars.dropFirst(low)); newPage()
                }
            case .image: place(block, height: 330)
            case .pdf: newPage(); place(block, height: bottom - margin - 12); newPage()
            case .gap: if y + 24 < bottom { y += 24 }
            }
        }
        return pages.filter { !$0.isEmpty }
    }
    private func draw(_ placed: Placed, context: CGContext) {
        switch placed.block {
        case .title(let text): (text as NSString).draw(with: placed.rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes(title: true), context: nil)
        case .text(let text): (text as NSString).draw(with: placed.rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes(), context: nil)
        case .image(let url, let caption):
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2000
               ] as CFDictionary) {
                let image = UIImage(cgImage: thumbnail)
                let area = CGRect(x: placed.rect.minX, y: placed.rect.minY, width: placed.rect.width, height: placed.rect.height - 42)
                let ratio = min(area.width / image.size.width, area.height / image.size.height)
                let rect = CGRect(x: area.midX - image.size.width * ratio / 2, y: area.minY, width: image.size.width * ratio, height: image.size.height * ratio)
                image.draw(in: rect)
            }
            (caption as NSString).draw(in: CGRect(x: placed.rect.minX, y: placed.rect.maxY - 36, width: placed.rect.width, height: 36), withAttributes: attributes())
        case .pdf(let url, let index):
            if let page = PDFDocument(url: url)?.page(at: index)?.pageRef {
                context.saveGState()
                context.translateBy(x: placed.rect.minX, y: placed.rect.maxY); context.scaleBy(x: 1, y: -1)
                let area = CGRect(origin: .zero, size: placed.rect.size)
                context.concatenate(page.getDrawingTransform(.mediaBox, rect: area, rotate: 0, preserveAspectRatio: true))
                context.drawPDFPage(page); context.restoreGState()
            }
        case .gap: break
        }
    }
    private func drawCover(_ record: MoveCase, generatedAt: Date) {
        ink.setFill(); UIBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: 12)).fill()
        ("LeaveWell" as NSString).draw(at: CGPoint(x: margin, y: 70), withAttributes: attributes(title: true))
        let title = L("Move-Out Condition Record")
        (title as NSString).draw(in: CGRect(x: margin, y: 210, width: width - 2 * margin, height: 150), withAttributes: [.font: UIFont.systemFont(ofSize: 38, weight: .semibold), .foregroundColor: ink])
        let details = [record.address, L("Tenant") + ": " + record.tenant,
                       L("Move-out date") + ": " + record.moveDate.formatted(date: .long, time: .omitted),
                       L("Report created") + ": " + stamp(generatedAt), record.reference].joined(separator: "\n\n")
        (details as NSString).draw(in: CGRect(x: margin, y: 385, width: width - margin * 2, height: 300), withAttributes: attributes())
    }
    private func footer(_ reference: String, page: Int, total: Int) {
        let text = reference + " · " + L("Page") + " \(page) / \(total)"
        (text as NSString).draw(in: CGRect(x: margin, y: height - 43, width: width - margin * 2, height: 26), withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.secondaryLabel])
    }
}

enum ReportError: LocalizedError {
    case unreadableOriginal
    var errorDescription: String? { L("An included image or PDF could not be opened. Check the original file or exclude it from this report before trying again.") }
}
