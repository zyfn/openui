import Foundation
import XCTest
@testable import OpenUISwiftUI

final class MarkdownDelimiterTests: XCTestCase {
  func testChinesePunctuationBoundaryMatchesCommonMarkAndHasASafeAuthoringForm() throws {
    let source = "**想一次玩够选上海，想省力省钱选香港。**下面把影响决定的几项摊开。"
    let prepared = try NativeRichTextEngine.shared.prepare(source, mode: .textContent, sources: [])
    XCTAssertEqual(String(NativeInlineMarkdown.attributed(prepared).characters).trimmingCharacters(in: .whitespacesAndNewlines), source)
    let corrected = "**想一次玩够选上海，想省力省钱选香港**。下面把影响决定的几项摊开。"
    let readable = NativeInlineMarkdown.attributed(try NativeRichTextEngine.shared.prepare(corrected, mode: .textContent, sources: []))
    XCTAssertEqual(String(readable.characters).trimmingCharacters(in: .whitespacesAndNewlines), "想一次玩够选上海，想省力省钱选香港。下面把影响决定的几项摊开。")
    XCTAssertTrue(readable.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
  }
  func testValidChineseEmphasisRendersWithoutMarkersAfterPreparation() throws {
    for source in ["**重点**", "前文。 **想一次玩够选上海，想省力省钱选香港。** 后文。"] {
      let prepared = try NativeRichTextEngine.shared.prepare(source, mode: .textContent, sources: [])
      let attributed = NativeInlineMarkdown.attributed(prepared)
      XCTAssertFalse(String(attributed.characters).contains("**"))
      XCTAssertTrue(attributed.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }
  }
  func testSpacesInsideDelimitersAndEscapedOrCodeStarsRemainLiteral() throws {
    for source in ["** 重点 **", "**重点 **", "\\*\\*重点\\*\\*", "`**重点**`"] {
      let prepared = try NativeRichTextEngine.shared.prepare(source, mode: .textContent, sources: [])
      let attributed = NativeInlineMarkdown.attributed(prepared)
      XCTAssertTrue(String(attributed.characters).contains("**"), source)
      XCTAssertFalse(attributed.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }, source)
    }
  }
}
