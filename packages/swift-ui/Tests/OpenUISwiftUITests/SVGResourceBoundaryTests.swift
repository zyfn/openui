import XCTest
@testable import OpenUISwiftUI

final class SVGResourceBoundaryTests: XCTestCase {
  func testOrdinarySVGRemainsValid() throws {
    let svg = #"<svg viewBox="0 0 320 180"><rect width="320" height="180"/></svg>"#
    XCTAssertEqual(try XCTUnwrap(NativeSVGDocument.parse(svg)).ratio, 320.0 / 180.0, accuracy: 0.001)
  }

  func testExtremeRatiosAreRejectedBeforeNativeFitting() {
    XCTAssertNil(NativeSVGDocument.parse(#"<svg viewBox="0 0 100000000 1"/>"#))
    XCTAssertNil(NativeSVGDocument.parse(#"<svg viewBox="0 0 1 100000000"/>"#))
  }

  func testDeepNestingAndExcessiveElementsAreRejected() {
    let nested = #"<svg viewBox="0 0 10 10">"# + String(repeating: "<g>", count: 140)
      + String(repeating: "</g>", count: 140) + "</svg>"
    XCTAssertNil(NativeSVGDocument.parse(nested))
    let many = #"<svg viewBox="0 0 10 10">"# + String(repeating: "<path d=\"M0 0\"/>", count: 10_100) + "</svg>"
    XCTAssertNil(NativeSVGDocument.parse(many))
  }

  func testExternalEntitiesAndScriptAreRejected() {
    XCTAssertNil(NativeSVGDocument.parse(#"<!DOCTYPE svg [<!ENTITY e SYSTEM "https://example.com/">]><svg viewBox="0 0 10 10"/>"#))
    XCTAssertNil(NativeSVGDocument.parse(#"<svg viewBox="0 0 10 10"><script>bad()</script></svg>"#))
  }
}
