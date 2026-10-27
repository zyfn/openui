import XCTest

final class ReviewScenarioTests: ReviewTestCase {
  func testSixTaskSourcesHaveMatchingBatchAndStreamingTrees() throws {
    let report = try matrixReport()
    XCTAssertEqual(report["variants"] as? Int, 6)
    XCTAssertEqual((report["scenarios"] as? [[String: Any]])?.count, 6)
    XCTAssertEqual((report["duplicateProgramIDs"] as? [String])?.count, 0)
    XCTAssertEqual((report["failures"] as? [String: Any])?.count, 0,
      "Six task programs must preserve complete batch and streaming results: \(report["failures"] ?? "")")
    // Registration coverage remains informational; these six tasks do not claim
    // to exhaustively demonstrate every SDK component or state.
  }
}
