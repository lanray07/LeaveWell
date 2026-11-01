import XCTest
@testable import LeaveWell

final class LocalizationTests: XCTestCase {
    func testStringCatalogIsCompiledIntoUsableLanguageBundles() throws {
        // A raw .xcstrings file copied into the app passed source-only checks
        // but left every language using English. Exercise the built resources.
        for locale in ["en-GB", "fr", "es", "de", "it", "pt-BR", "nl", "pl", "ar", "hi", "ja", "ko", "zh-Hans", "zh-Hant", "tr", "id", "sv"] {
            XCTAssertNotNil(Bundle.main.path(forResource: locale, ofType: "lproj"), "Missing compiled language bundle: \(locale)")
        }
        let french = try XCTUnwrap(Bundle(path: XCTUnwrap(Bundle.main.path(forResource: "fr", ofType: "lproj"))))
        let arabic = try XCTUnwrap(Bundle(path: XCTUnwrap(Bundle.main.path(forResource: "ar", ofType: "lproj"))))
        XCTAssertEqual(french.localizedString(forKey: "Kitchen", value: nil, table: "Localizable"), "Cuisine")
        XCTAssertEqual(arabic.localizedString(forKey: "Kitchen", value: nil, table: "Localizable"), "المطبخ")
    }
}
