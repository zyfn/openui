import Foundation
import XCTest
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
  func testInlinePreviewPreservesSignedURLsAndDoesNotRewriteCodeOrExistingLinks() throws {
    let source = "Text ![Diagram](https://example.com/a.png?sig=a%26b&x=2) tail"
    let prepared = try NativeRichTextEngine.shared.prepare(source, mode: .textContent, sources: [])
    let target = try XCTUnwrap(NativeInlineMarkdown.attributed(prepared).runs.compactMap(\.link).first { $0.scheme == "openui-image" })
    let preview = try XCTUnwrap(NativeMarkdownImageLink(target))
    XCTAssertEqual(preview.source, "https://example.com/a.png?sig=a%26b&x=2")
    XCTAssertEqual(preview.alt, "Diagram")
    for literal in ["`![x](https://example.com/a.png)`", "[![x](https://example.com/a.png)](https://example.com/details)", "![x](https://example.com/a.png)"] {
      XCTAssertFalse(try NativeRichTextEngine.shared.prepare(literal, mode: .textContent, sources: []).contains("openui-image:"))
    }
  }
}
