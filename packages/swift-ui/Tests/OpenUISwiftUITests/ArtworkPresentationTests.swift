#if os(macOS)
import AppKit
import Foundation
import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class ArtworkPresentationTests: XCTestCase {
  @MainActor func testArtworkUsesNeutralCopyUntilPixelsLoadAndResetsOnSourceChange() throws {
    _ = NSApplication.shared
    let probe = ArtworkStyleProbe()
    let loader = ArtworkImageLoader()
    let standard = try OpenUIStandardComponents.library()
    let title = try XCTUnwrap(standard.library.components.first { $0.name == "BoldText" })
    let tag = try XCTUnwrap(standard.library.components.first { $0.name == "Tag" })
    let library = try standard.extending(overriding: [
      OpenUIComponent(title) { context in
        MainActor.assumeIsolated { probe.titleInk = context.theme.textNeutralPrimary }
        return NativeInlineText(context: context, bold: true)
      },
      OpenUIComponent(tag) { context in
        MainActor.assumeIsolated {
          probe.tagInk = context.theme.textNeutralPrimary
          probe.tagSurface = context.theme.foreground
        }
        return NativeTag(context: context)
      },
    ])
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("root=VisualCardItem(BoldText(\"text\",$copy),\"card\",$photo,Tag(\"Place\"),\"Photo\")\n$photo=\"https://images.example/a.png\"\n$copy=\"Visible title\"")
    XCTAssertTrue(state.errors.isEmpty)
    let base = OpenUIThemeValues()
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry)
      .openUITheme(base).openUIResourceContext(.init(loader: loader))
      .environment(\.colorScheme, .light).frame(width: 320))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.appearance = NSAppearance(named: .aqua)
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    func settle(_ condition: () -> Bool) {
      let deadline = Date().addingTimeInterval(3)
      repeat {
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
      } while !condition() && Date() < deadline
      XCTAssertTrue(condition())
    }
    settle { loader.count == 1 && probe.titleInk != nil }
    XCTAssertEqual(probe.titleInk, base.textNeutralPrimary, "Loading copy must not be white on a neutral placeholder")
    func assertNeutralPlaceholder() throws {
      let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
      host.cacheDisplay(in: host.bounds, to: bitmap)
      let color = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 12, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
      XCTAssertGreaterThan(min(color.redComponent, color.greenComponent, color.blueComponent), 0.5,
        "The light appearance must not paint a black artwork placeholder")
    }
    try assertNeutralPlaceholder()
    let loadingSize = host.fittingSize
    settle { probe.titleInk == .white }
    XCTAssertEqual(host.fittingSize, loadingSize, "Loading does not change the photo or copy allocation")
    XCTAssertEqual(probe.tagInk, base.textNeutralPrimary, "The tag must not inherit white photo-overlay ink")
    XCTAssertEqual(probe.tagSurface, base.foreground, "The tag keeps the opaque host surface")
    XCTAssertEqual(loader.count, 1, "Changing copy appearance must not refetch the image")
    state.setState("$copy", value: .string(String(repeating: "Complete photo descriptions stay readable when moved below the image. ", count: 12)))
    settle { probe.titleInk == base.textNeutralPrimary }
    XCTAssertGreaterThan(host.fittingSize.height, loadingSize.height,
      "Overflowing copy reflows below the unchanged photo, with normal host ink")
    XCTAssertEqual(loader.count, 1, "Moving copy must preserve the mounted image request")
    state.setState("$copy", value: .string("Visible title"))
    settle { probe.titleInk == .white }
    XCTAssertEqual(host.fittingSize, loadingSize, "Short copy can return to the photo overlay")
    state.setState("$photo", value: .string("invalid://unavailable"))
    settle { probe.titleInk == base.textNeutralPrimary }
    try assertNeutralPlaceholder()
    XCTAssertEqual(host.fittingSize, loadingSize)
    XCTAssertEqual(probe.tagInk, base.textNeutralPrimary)
    XCTAssertEqual(loader.count, 1)
  }

  @MainActor func testArtworkTagPlateRetainsPhotoTransparency() throws {
    _ = NSApplication.shared
    let theme = OpenUIThemeValues()
    func pixels(_ background: Color) throws -> (Int, Int, Data) {
      let tag = NativeTagPill(text: "Confirmed", size: "sm", variant: "success", theme: theme) { EmptyView() }
        .environment(\.openUIArtworkTag, true).fixedSize()
      let renderer = ImageRenderer(content: tag.background(background).environment(\.colorScheme, .light))
      renderer.scale = 2
      let image = try XCTUnwrap(renderer.cgImage)
      let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return (image.width, image.height, Data(bytes: try XCTUnwrap(context.data), count: image.width * image.height * 4))
    }
    let dark = try pixels(.black), bright = try pixels(.white)
    XCTAssertEqual(dark.0, bright.0); XCTAssertEqual(dark.1, bright.1)
    // The central rectangle is inside the rounded plate; corner pixels may
    // correctly show the photograph outside its contour.
    var changedChannels = 0
    for y in (dark.1 / 4)..<(dark.1 * 3 / 4) {
      for x in (dark.0 / 5)..<(dark.0 * 4 / 5) {
        let index = (y * dark.0 + x) * 4
        for channel in 0..<4 {
          if dark.2[index + channel] != bright.2[index + channel] { changedChannels += 1 }
        }
      }
    }
    XCTAssertGreaterThan(changedChannels, 0, "The capsule must retain photograph translucency instead of painting an opaque sticker")
  }
}

@MainActor private final class ArtworkStyleProbe {
  var titleInk: Color?
  var tagInk: Color?
  var tagSurface: Color?
}

private final class ArtworkImageLoader: OpenUIResourceLoading {
  private let lock = NSLock()
  private var requests = 0
  var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
  func request(for source: String, relativeTo baseURL: URL?) -> URLRequest? {
    guard let url = URL(string: source, relativeTo: baseURL), url.scheme == "https" else { return nil }
    return URLRequest(url: url)
  }
  private func record() { lock.lock(); requests += 1; lock.unlock() }
  func data(for request: URLRequest) async throws -> Data {
    record()
    try await Task.sleep(nanoseconds: 500_000_000)
    return Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=")!
  }
}
#endif
