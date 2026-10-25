import CryptoKit
import SwiftUI
import UIKit

/// Review-host export only. Capture the visible native window at actual scroll
/// offsets, preserve every original viewport, and join non-overlapping strips.
/// SDK views keep their normal on-screen size and layout throughout capture.
@MainActor
final class ReviewPageCapture: ObservableObject {
  weak var scrollView: UIScrollView?
  private var exporting = false

  func export(programID: String, language: String, source: String, request: String?, diagnostics: [String]) async {
    guard !exporting else { return }
    exporting = true
    defer { exporting = false }
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Exports").appendingPathComponent(programID)
    do {
      if FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.removeItem(at: directory)
      }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try Data(source.utf8).write(to: directory.appendingPathComponent("program.openui"))
      if let request { try Data(request.utf8).write(to: directory.appendingPathComponent("request.txt")) }
      for _ in 0..<30 {
        if scrollView?.window != nil { break }
        try await Task.sleep(nanoseconds: 100_000_000)
      }
      guard let scroll = scrollView, let window = scroll.window else { throw CaptureError.missingScroll }
      // Allow native map tiles, charts and bundled images to finish drawing.
      try await Task.sleep(nanoseconds: 2_000_000_000)
      let originalOffset = scroll.contentOffset
      let indicator = scroll.showsVerticalScrollIndicator
      scroll.showsVerticalScrollIndicator = false
      defer {
        scroll.setContentOffset(originalOffset, animated: false)
        scroll.showsVerticalScrollIndicator = indicator
      }
      let viewport = scroll.convert(scroll.bounds, to: window).intersection(window.bounds)
      let height = scroll.contentSize.height
      guard viewport.width > 0, viewport.height > 0, height > 0, height < 30_000,
        abs(scroll.adjustedContentInset.top) < 0.5 else { throw CaptureError.invalidGeometry }
      let format = UIGraphicsImageRendererFormat()
      format.scale = window.screen.scale
      format.opaque = true
      var images: [(offset: CGFloat, image: UIImage)] = []
      var frames: [[String: Any]] = []
      var target: CGFloat = 0
      while true {
        try Task.checkCancellation()
        scroll.setContentOffset(CGPoint(x: 0, y: target), animated: false)
        window.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 450_000_000)
        let offset = scroll.contentOffset.y
        guard abs(scroll.contentSize.height - height) < 1 else { throw CaptureError.changedLayout }
        var drawn = false
        let phone = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
          drawn = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard drawn, let pixels = phone.cgImage,
          let crop = pixels.cropping(to: CGRect(x: viewport.minX * format.scale,
            y: viewport.minY * format.scale, width: viewport.width * format.scale,
            height: viewport.height * format.scale).integral) else { throw CaptureError.captureFailed }
        let image = UIImage(cgImage: crop, scale: format.scale, orientation: .up)
        let name = String(format: "viewport-%02d.png", images.count + 1)
        try write(phone, to: directory.appendingPathComponent(name))
        if images.isEmpty {
          try write(phone, to: directory.appendingPathComponent("phone.png"))
        }
        images.append((offset, image))
        frames.append(["file": name, "contentOffsetY": offset,
          "viewport": ["x": viewport.minX, "y": viewport.minY,
            "width": viewport.width, "height": viewport.height]])
        let maximum = max(0, height - viewport.height)
        if offset >= maximum - 0.5 { break }
        let next = min(maximum, offset + viewport.height - 24)
        guard next > offset + 1 else { throw CaptureError.invalidGeometry }
        target = next
      }
      let full = UIGraphicsImageRenderer(size: CGSize(width: viewport.width, height: height), format: format)
        .image { context in
          UIColor.systemBackground.setFill()
          context.fill(CGRect(x: 0, y: 0, width: viewport.width, height: height))
          var covered: CGFloat = 0
          for frame in images {
            let end = min(height, frame.offset + viewport.height)
            context.cgContext.saveGState()
            context.cgContext.clip(to: CGRect(x: 0, y: covered, width: viewport.width, height: end - covered))
            frame.image.draw(at: CGPoint(x: 0, y: frame.offset))
            context.cgContext.restoreGState()
            covered = end
          }
        }
      try write(full, to: directory.appendingPathComponent("full-content.png"))
      let manifest: [String: Any] = [
        "kind": programID.hasPrefix("scene-") ? "authored-sdk-demo" : "saved-program-review",
        "program": programID, "language": language,
        "languageDiagnostics": diagnostics,
        "sourceSHA256": SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined(),
        "method": "Native visible-window captures joined at recorded content offsets; no layout resizing or image retouching",
        "scale": format.scale, "width": viewport.width, "height": height,
        "frames": frames, "complete": true,
      ]
      try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
    } catch {
      try? Data(String(describing: error).utf8).write(to: directory.appendingPathComponent("error.txt"))
    }
  }

  private func write(_ image: UIImage, to url: URL) throws {
    guard let data = image.pngData() else { throw CaptureError.captureFailed }
    try data.write(to: url, options: .atomic)
  }

  private enum CaptureError: Error {
    case missingScroll, invalidGeometry, changedLayout, captureFailed
  }
}

struct ReviewScrollLocator: UIViewRepresentable {
  let capture: ReviewPageCapture
  func makeUIView(context: Context) -> UIView { Locator(capture: capture) }
  func updateUIView(_ uiView: UIView, context: Context) {}

  private final class Locator: UIView {
    let capture: ReviewPageCapture
    init(capture: ReviewPageCapture) {
      self.capture = capture
      super.init(frame: .zero)
      isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() {
      super.didMoveToWindow()
      var ancestor = superview
      while let view = ancestor {
        if let scroll = view as? UIScrollView { capture.scrollView = scroll; break }
        ancestor = view.superview
      }
    }
  }
}
