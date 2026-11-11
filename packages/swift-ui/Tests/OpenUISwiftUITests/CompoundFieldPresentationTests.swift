#if os(macOS)
import AppKit
import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class CompoundFieldPresentationTests: XCTestCase {
  @MainActor private func height(_ source: String, library: OpenUIComponentLibrary) throws -> CGFloat {
    _ = NSApplication.shared
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource(source)
    XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
    return host.fittingSize.height
  }
  @MainActor func testSliderAndFormControlShareOneHeadingWithoutASecondValueRow() throws {
    let library = try OpenUIStandardComponents.library()
    let slider = "Slider(\"budget\",\"continuous\",0,1000,50,[600],\"Budget\")"
    let direct = try height("root=" + slider, library: library)
    let grouped = try height("root=FormControl(\"Budget\",\(slider))", library: library)
    XCTAssertEqual(grouped, direct, accuracy: 1, "The surrounding FormControl must not add a second heading above the slider's value")
    XCTAssertLessThan(direct, 110)
  }
  @MainActor func testCustomRendererRetainsItsExternalLabelAndDefinitionReplacementRetainsNativeCapability() throws {
    let standard = try OpenUIStandardComponents.library()
    let component = try XCTUnwrap(OpenUIStandardComponents.components.first { $0.definition.name == "Slider" })
    XCTAssertTrue(component.replacingDefinition(component.definition).ownsFormControlLabel)
    let custom = try standard.extending(overriding: [OpenUIComponent(component.definition) { _ in Color.clear.frame(height: 40) }])
    XCTAssertFalse(custom.registry.ownsFormControlLabel("Slider"))
    let direct = try height("root=Slider(\"budget\",\"continuous\",0,1000)", library: custom)
    let grouped = try height("root=FormControl(\"Budget\",Slider(\"budget\",\"continuous\",0,1000))", library: custom)
    XCTAssertGreaterThan(grouped, direct + 20, "A replacement renderer must not silently lose the surrounding field label")
  }
}
#endif
