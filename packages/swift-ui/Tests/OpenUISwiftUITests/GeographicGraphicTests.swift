import XCTest
import OpenUILang
@testable import OpenUISwiftUI

final class GeographicGraphicTests: XCTestCase {
  @MainActor func testDefaultLibraryOwnsExistingHostContractsAndContainerSlots() throws {
    let library = try OpenUIStandardComponents.library()
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples/agent-cases/test-library-spec.json")
    let previous = try LibrarySpec(jsonString: String(contentsOf: fixture, encoding: .utf8))
    for name in ["Map", "MapPoint", "SVG", "Card", "TabItem", "AccordionItem"] {
      XCTAssertEqual(library.toSpec().components.first { $0.name == name }?.signature,
                     previous.components.first { $0.name == name }?.signature, name)
    }
    let state = OpenUIState(schema: library.library.toSchema())
    for source in [
      "root=Card([Map([MapPoint(\"A\",30,120)])])",
      "root=Tabs([TabItem(\"a\",\"A\",[SVG(\"<svg viewBox='0 0 2 1'/>\")])])",
      "root=Accordion([AccordionItem(\"a\",\"A\",[Map([MapPoint(\"A\",30,120)])])])"
    ] { state.setSource(source); XCTAssertTrue(state.errors.isEmpty, "\(source): \(state.errors)") }
  }
  func testSVGRequiresFinitePositiveViewBoxAndRejectsActiveOrExternalContent() {
    XCTAssertEqual(NativeSVGDocument.parse("<svg viewBox='0 0 200 100'><path d='M0 0 L10 10'/></svg>")?.ratio, 2)
    for source in ["<svg/>", "<svg viewBox='0 0 0 1'/>", "<svg viewBox='0 0 NaN 1'/>",
      "<svg viewBox='0 0 1 1'><script>alert(1)</script></svg>",
      "<svg viewBox='0 0 1 1' onload='x()'/>",
      "<svg viewBox='0 0 1 1'><image href='https://example.com/a.png'/></svg>",
      "<!DOCTYPE svg [<!ENTITY x 'a'>]><svg viewBox='0 0 1 1'/>",
      "<svg viewBox='0 0 1 1'><foreignObject/></svg>",
      "<svg viewBox='0 0 1 1'><animateMotion dur='1s'/></svg>",
      "<svg viewBox='0 0 1e308 1e-308'/>",
      "<svg viewBox='0 0 1e-308 1e308'/>",
      "<svg viewBox='0 0 1 1' preserveAspectRatio='none'/>"] {
      XCTAssertNil(NativeSVGDocument.parse(source), source)
    }
    XCTAssertNil(NativeSVGDocument.parse(String(repeating: "x", count: 1_000_001)))
  }
  @MainActor func testMapKeepsPlaceIdentityWhenOptionalMetadataArrives() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    func decode(_ source: String) -> [NativeMapPlace] {
      state.setSource(source)
      return NativeMapPlace.decode(PropValue.value(state.root!, "points"), crs: "wgs84")
    }
    let first = decode("root=Map([MapPoint(\"A\",30,120)])")
    let next = decode("root=Map([MapPoint(\"B\",31,121),MapPoint(\"A\",30,120,null,null,\"Details\")])")
    XCTAssertEqual(first[0].id, next[1].id)
    XCTAssertEqual(decode("root=Map([MapPoint(\"A\",30,120),MapPoint(\"A\",30,120),MapPoint(\"Bad\",91,120)])").count, 1)
    XCTAssertTrue(NativeMapPlace.decode(nil, crs: "unknown").isEmpty)
  }
  func testCoordinateConversionLeavesWGS84AndOutsideChinaAlone() {
    let wgs = NativeMapCoordinates.wgs84(latitude: 30.25, longitude: 120.15, source: "wgs84")
    XCTAssertEqual(wgs.latitude, 30.25)
    let paris = NativeMapCoordinates.wgs84(latitude: 48.85, longitude: 2.35, source: "gcj02")
    XCTAssertEqual(paris.longitude, 2.35)
    let converted = NativeMapCoordinates.wgs84(latitude: 39.910226, longitude: 116.403714, source: "gcj02")
    XCTAssertEqual(converted.latitude, 39.908823, accuracy: 0.00001)
    XCTAssertEqual(converted.longitude, 116.397470, accuracy: 0.00001)
    XCTAssertNil(NativeMapValue.url("https://user:secret@example.com", baseURL: nil))
    XCTAssertNil(NativeMapValue.url("javascript:alert(1)", baseURL: nil))
  }
}
