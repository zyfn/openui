import XCTest
@testable import OpenUILang

final class RuntimeLimitsTests: XCTestCase {
    func testSourceBudgetPreservesOperatorAndDepthBoundaries() {
        XCTAssertFalse(sourceExceedsLimits("root=" + Array(repeating: "1", count: 257).joined(separator: "+")))
        XCTAssertTrue(sourceExceedsLimits("root=" + Array(repeating: "1", count: 258).joined(separator: "+")))
        XCTAssertFalse(sourceExceedsLimits("root=" + String(repeating: "[", count: 128) + "1" + String(repeating: "]", count: 128)))
        XCTAssertTrue(sourceExceedsLimits("root=" + String(repeating: "[", count: 129) + "1"))
    }

    func testSourceBudgetMatchesTheExistingTokenGuard() {
        let expressions = [
            "root=Text(\"++++[[[ punctuation is text\")",
            "$value=1\nroot=Text(\"value\")",
            "root=Stack([Text(\"unfinished",
            "root=1?2:3\nnext=" + Array(repeating: "1", count: 258).joined(separator: "+"),
        ]
        for source in expressions {
            let reference = splitStatements(tokenize(source)).contains { expressionExceedsLimits($0.tokens) }
            XCTAssertEqual(sourceExceedsLimits(source), reference, source)
        }
    }
}
