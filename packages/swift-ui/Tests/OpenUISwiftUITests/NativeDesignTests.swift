import OpenUILang
import SwiftUI
import XCTest

@testable import OpenUISwiftUI

final class NativeDesignTests: XCTestCase {
    func testAccentForegroundChoosesReadableContrastForLightAndDarkAccents() {
        XCTAssertTrue(NativeControlPalette.prefersDarkForeground(red: 1, green: 1, blue: 1))
        XCTAssertTrue(NativeControlPalette.prefersDarkForeground(red: 1, green: 0.9, blue: 0.2))
        XCTAssertFalse(NativeControlPalette.prefersDarkForeground(red: 0, green: 0, blue: 0))
        XCTAssertFalse(NativeControlPalette.prefersDarkForeground(red: 0.12, green: 0.44, blue: 0.34))
        XCTAssertFalse(NativeControlPalette.prefersDarkForeground(red: 0.345, green: 0.337, blue: 0.839))
    }

    func testControlStringsFollowTheScopedLocale() {
        XCTAssertEqual(
            NativeControlText.localized("Start date", locale: Locale(identifier: "zh-Hans")), "开始日期")
        XCTAssertEqual(NativeControlText.localized("End date", locale: Locale(identifier: "zh_CN")), "结束日期")
        XCTAssertEqual(NativeControlText.localized("Select", locale: Locale(identifier: "en_US")), "Select")
    }

    @MainActor func testPendingCalendarRetainsTheSourceThatOpenedIt() throws {
        let library = try OpenUIStandardComponents.library()
        let state = OpenUIState(schema: library.library.toSchema())
        state.setSource("$date=null\nroot=DatePicker(\"date\",\"single\",null,$date)")
        let context = OpenUIComponentContext(
            element: try XCTUnwrap(state.root), registry: library.registry, state: state)
        let field = NativeFieldState(context: context)
        field.initialize()
        let before = state.snapshotState()
        let request = NativeDateRequest(part: .single, label: "Date", date: Date(), context: context)
        XCTAssertEqual(state.snapshotState(), before, "Opening a calendar must not commit today's date")
        state.setSource("root=TextContent(\"A different response\")")
        NativeFieldState(context: request.context).write(NativeCalendarDate.encode(request.date))
        XCTAssertFalse(request.context.canInteract)
        XCTAssertEqual(
            state.stateValue("$date"), .null, "A stale calendar must not write to a replacement response")
    }
}
