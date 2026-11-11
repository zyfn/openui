import Foundation
import XCTest
import MarkdownUI
@testable import OpenUISwiftUI

final class ImageInteractionTests: XCTestCase {
  func testRetryAttemptsBelongToTheExactSourceAndResourceOwner() {
    let a = OpenUIURLSessionResourceLoader(), b = OpenUIURLSessionResourceLoader()
    let url = URL(string: "https://example.com/image.png?signature=a%26b")!
    let first = NativeResourceRequestID(request: URLRequest(url: url), loader: ObjectIdentifier(a), attempt: 0)
    let otherOwner = NativeResourceRequestID(request: URLRequest(url: url), loader: ObjectIdentifier(b), attempt: 0)
    var retry = NativeImageRetryState()
    retry.retry(first); retry.retry(first)
    XCTAssertEqual(retry.attempt(for: first), 2)
    XCTAssertEqual(retry.attempt(for: otherOwner), 0)
    retry.retry(otherOwner)
    XCTAssertEqual(retry.attempt(for: otherOwner), 1)
    XCTAssertEqual(retry.attempt(for: first), 0)
  }
  func testParagraphPhotosBecomeInteractiveBlocksWithoutChangingTheirSignedURLs() throws {
    let source = "Text ![Diagram](https://example.com/a.png?sig=a%26b&x=2) tail"
    let prepared = try NativeRichTextEngine.shared.prepare(source, mode: .textContent, sources: [])
    let html = MarkdownContent(prepared).renderHTML()
    let first = try XCTUnwrap(html.range(of: "<p>Text"))
    let photo = try XCTUnwrap(html.range(of: "<p><img"))
    let last = try XCTUnwrap(html.range(of: "tail</p>"))
    XCTAssertLessThan(first.lowerBound, photo.lowerBound)
    XCTAssertLessThan(photo.lowerBound, last.lowerBound)
    XCTAssertTrue(html.contains("src=\"https://example.com/a.png?sig=a%26b&amp;x=2\""))
    let linked = try NativeRichTextEngine.shared.prepare("Before [![x](https://example.com/a.png)](https://example.com/details) after", mode: .textContent, sources: [])
    XCTAssertTrue(MarkdownContent(linked).renderHTML().contains("href=\"https://example.com/details\""))
    let code = try NativeRichTextEngine.shared.prepare("`![x](https://example.com/a.png)`", mode: .textContent, sources: [])
    XCTAssertTrue(code.contains("`![x](https://example.com/a.png)`"))
    let math = try NativeRichTextEngine.shared.prepare("Formula $$x^2$$ tail", mode: .textContent, sources: [])
    XCTAssertFalse(math.contains("\n\n!["), "Inline equations retain inline semantics")
  }
}
