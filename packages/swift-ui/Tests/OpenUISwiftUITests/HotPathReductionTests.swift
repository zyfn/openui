import Foundation
import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class HotPathReductionTests: XCTestCase {
  func testPagerHeightMatchesReferenceForDegenerateInputsAndSelection() {
    let cases: [[CGFloat]] = [[], [0], [-1, -100], [.nan, .infinity, -.infinity],
      [.nan, -2, 12, 48, .infinity], [0, 100, 50], [.greatestFiniteMagnitude, 2]]
    for heights in cases {
      let expected = heights.filter(\.isFinite).map { max(0, $0) }.max() ?? 0
      for selected in [-1, 0, 1, 100] {
        XCTAssertEqual(NativePagerContentHeight.measure(heights, selected: selected,
          translation: 25, stride: 300), expected)
      }
    }
  }

  func testPagerHeightReferenceEquivalenceAcrossDeterministicSamples() {
    var seed: UInt64 = 0x173B
    for length in 0...100 {
      var heights: [CGFloat] = []
      for _ in 0..<length {
        seed = seed &* 6364136223846793005 &+ 1
        heights.append(CGFloat(Int(seed % 2001) - 1000) / 4)
      }
      let expected = heights.filter(\.isFinite).map { max(0, $0) }.max() ?? 0
      XCTAssertEqual(NativePagerContentHeight.measure(heights, selected: length / 2), expected)
    }
  }

  func testTableCountMatchesReferenceThroughEditResetCommitAndReload() {
    var draft = NativeTableDraft()
    let source = rows([("a", [.number(1), .string("one")]), ("b", []),
      ("c", [.null, .number(3)])])
    draft.load(source)
    var baseline = draft.rows
    check(draft, baseline: baseline)
    draft.write(.string("changed"), row: 0, column: 1)
    draft.write(.number(9), row: 1, column: 3)
    check(draft, baseline: baseline)
    draft.reset()
    check(draft, baseline: baseline)
    XCTAssertFalse(draft.hasChanges)
    draft.write(.number(10), row: 2, column: 0)
    draft.commit()
    baseline = draft.rows
    check(draft, baseline: baseline)
    XCTAssertEqual(draft.changes(columns: 4), 0)
    draft.load(rows([("new", [.string("different")])]))
    check(draft, baseline: draft.rows)
  }

  func testTablePreservesFirstDuplicateIDAndCodeUnitIdentity() {
    var draft = NativeTableDraft()
    draft.load(rows([("same", [.number(1)]), ("same", [.number(2)]),
      (OpenUIString("\u{00E9}"), [.number(3)]),
      (OpenUIString("e\u{0301}"), [.number(4)])]))
    let baseline = draft.rows
    // This test preserves the existing first-match policy. It does not declare
    // duplicate IDs safe for editable row identity; that is a separate task.
    XCTAssertEqual(draft.changes(columns: 1), 1)
    draft.write(.number(5), row: 3, column: 0)
    check(draft, baseline: baseline)
    XCTAssertEqual(draft.changes(columns: 1), 2)
  }

  func testLargeTableCountMatchesReferenceWithoutRetainedIndexState() {
    var draft = NativeTableDraft()
    draft.load(rows((0..<1000).map { (OpenUIString("row-\($0)"), [.number(Double($0))]) }))
    let baseline = draft.rows
    for index in stride(from: 0, to: 1000, by: 7) {
      draft.write(.number(-1), row: index, column: 0)
    }
    check(draft, baseline: baseline)
    let expected = reference(draft.rows, baseline: baseline, columns: 1)
    for _ in 0..<20 { XCTAssertEqual(draft.changes(columns: 1), expected) }
    draft.reset()
    XCTAssertEqual(draft.changes(columns: 1), 0)
  }

  private func rows(_ records: [(OpenUIString, [Value])]) -> Value {
    .array(records.map { .object([
      ObjectField(key: "id", value: .string($0.0)),
      ObjectField(key: "values", value: .array($0.1))
    ]) })
  }

  private func check(_ draft: NativeTableDraft, baseline: [NativeTableDraft.Row],
                     file: StaticString = #filePath, line: UInt = #line) {
    for columns in [0, 1, 2, 4, 8] {
      XCTAssertEqual(draft.changes(columns: columns),
        reference(draft.rows, baseline: baseline, columns: columns), file: file, line: line)
    }
  }

  private func reference(_ rows: [NativeTableDraft.Row], baseline: [NativeTableDraft.Row], columns: Int) -> Int {
    rows.reduce(0) { count, row in
      guard let previous = baseline.first(where: { $0.id == row.id }) else { return count }
      return count + (0..<columns).filter { index in
        let a = row.values.indices.contains(index) ? row.values[index] : .undefined
        let b = previous.values.indices.contains(index) ? previous.values[index] : .undefined
        return a != b
      }.count
    }
  }
}
