import Foundation

func L(_ key: String) -> String {
    NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
}

extension Condition {
    var title: String {
        switch self {
        case .noIssue: L("No issue noted")
        case .issue: L("Issue documented")
        case .notApplicable: L("Not applicable")
        }
    }
}

enum Jurisdictions {
    struct Region: Identifiable {
        let id: String
        let country: String
        let title: String
    }
    static let supported = [
        Region(id: "GB-ENG", country: "GB", title: "England"),
        Region(id: "GB-SCT", country: "GB", title: "Scotland"),
        Region(id: "GB-WLS", country: "GB", title: "Wales"),
        Region(id: "GB-NIR", country: "GB", title: "Northern Ireland"),
        Region(id: "OTHER", country: "", title: "Other region")
    ]
}
