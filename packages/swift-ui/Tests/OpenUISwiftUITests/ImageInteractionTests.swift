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
}
