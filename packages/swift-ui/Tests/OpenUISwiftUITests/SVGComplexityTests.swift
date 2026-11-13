import XCTest
@testable import OpenUISwiftUI

final class SVGComplexityTests: XCTestCase {
  func testValidSimpleSVGRemainsAccepted() {
    let document = NativeSVGDocument.parse("<svg viewBox=\"0 0 100 50\"><rect width=\"100\" height=\"50\"/></svg>")
    XCTAssertEqual(document?.ratio, 2)
  }

  func testRejectsExtremeViewBoxRatios() {
    XCTAssertNil(NativeSVGDocument.parse("<svg viewBox=\"0 0 100000000 1\"/>"))
    XCTAssertNil(NativeSVGDocument.parse("<svg viewBox=\"0 0 1 100000000\"/>"))
  }

  func testRejectsDeepAndLargeDocumentsWithinByteLimit() {
    let deeplyNested = "<svg viewBox=\"0 0 10 10\">" + String(repeating: "<g>", count: 130)
      + String(repeating: "</g>", count: 130) + "</svg>"
    XCTAssertNil(NativeSVGDocument.parse(deeplyNested))
    let tooManyElements = "<svg viewBox=\"0 0 10 10\">"
      + String(repeating: "<rect width=\"1\" height=\"1\"/>", count: 10_001) + "</svg>"
    XCTAssertNil(NativeSVGDocument.parse(tooManyElements))
  }
}
