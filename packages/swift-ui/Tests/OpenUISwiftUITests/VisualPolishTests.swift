import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI
#if os(macOS)
import AppKit
#endif

final class VisualPolishTests: XCTestCase {
  func testKnownTextRolesPreserveCompleteHostFontsAcrossRenderingAndMeasurement() {
    var theme = OpenUIThemeValues()
    theme.textBodySm = OpenUIFont(size: 23, weight: .light, family: "Custom", design: .serif,
      lineSpacing: 0.7, letterSpacing: 0.03).monospacedDigit()
    theme.textBodySmHeavy.weight = .black
    theme.textNeutralPrimary = .red
    theme.textNeutralSecondary = .blue
    let primary = theme.textStyle(.compactBody)
    let detail = theme.textStyle(.supporting)
    XCTAssertEqual(detail.font, theme.textBodySm)
    XCTAssertEqual(primary.font, detail.font)
    XCTAssertEqual(primary.color, .red)
    XCTAssertEqual(detail.color, .blue)
    XCTAssertEqual(detail.richText().font, detail.font)
    XCTAssertEqual(detail.richText().emphasisWeight, .black)
    XCTAssertEqual(detail.font.measuredLineHeight(scale: 2), theme.textBodySm.measuredLineHeight(scale: 2))
    theme.textBodySm.lineHeight = 2.2
    XCTAssertEqual(theme.textStyle(.supporting).font, theme.textBodySm,
      "Explicit leading and the whole host font survive role selection")
  }

  #if os(macOS)
  @MainActor private func height(_ source: String, width: CGFloat,
                                presentation: OpenUIPresentation = .init()) throws -> CGFloat {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource(source)
    XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
    return NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry)
      .openUIPresentation(presentation).dynamicTypeSize(.large).frame(width: width)).fittingSize.height
  }

  @MainActor func testRenderedThumbnailAdaptsLocallyButAuthoredSizesRemainExact() throws {
    let automatic = "root=ImageText(\"\",\"Object\",\"Object\",null,true,\"horizontal\")"
    XCTAssertEqual(try height(automatic, width: 296), 80, accuracy: 1)
    XCTAssertEqual(try height(automatic, width: 216), 64, accuracy: 1)
    let fixed = "root=ImageText(\"\",\"Object\",\"Object\",null,true,\"horizontal\",112)"
    for width: CGFloat in [216, 296] {
      XCTAssertEqual(try height(fixed, width: width), 112, accuracy: 1,
        "Narrow cards do not rewrite an explicit imageSize")
    }
    var custom = OpenUIPresentation()
    custom.inlineThumbnailSize = 104
    XCTAssertEqual(try height(automatic, width: 360, presentation: custom), 104, accuracy: 1)
  }

  private struct Raster {
    let width: Int
    let height: Int
    let pixels: Data
    func count(_ matches: (UInt8, UInt8, UInt8) -> Bool) -> Int {
      stride(from: 0, to: pixels.count, by: 4).filter { matches(pixels[$0], pixels[$0 + 1], pixels[$0 + 2]) }.count
    }
  }

  @MainActor private func raster(_ source: String, theme: OpenUITheme = .init(),
                                 presentation: OpenUIPresentation = .init(), width: CGFloat = 320) throws -> Raster {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource(source)
    XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry)
      .openUITheme(theme).openUIPresentation(presentation).dynamicTypeSize(.large).frame(width: width).padding(12).background(Color.white)
      .environment(\.colorScheme, .light))
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = host
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    // Mount the real presentation: an unmounted renderer intentionally disables
    // fields and therefore paints the disabled boundary, not the editable one.
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.08))
    window.setContentSize(host.fittingSize)
    host.layoutSubtreeIfNeeded()
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    let image = try XCTUnwrap(bitmap.cgImage)
    let canvas = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
      bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    canvas.setFillColor(CGColor(gray: 1, alpha: 1))
    canvas.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    canvas.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return Raster(width: image.width, height: image.height,
      pixels: Data(bytes: try XCTUnwrap(canvas.data), count: image.width * image.height * 4))
  }

  @MainActor func testSunkPaintsNoGroupingBorderWhileItsInputBoundaryRemainsVisible() throws {
    var theme = OpenUITheme()
    // Use fixed RGB primaries, not adaptive system red/blue swatches, so this
    // checks visible boundaries rather than platform color-space hue choices.
    theme.borderDefault = Color(red: 1, green: 0, blue: 0)
    theme.borderInteractive = Color(red: 0, green: 0, blue: 1)
    theme.interactiveAccentDefault = Color(red: 0, green: 0, blue: 1)
    let red: (UInt8, UInt8, UInt8) -> Bool = { $0 > 180 && $1 < 100 && $2 < 100 }
    let blue: (UInt8, UInt8, UInt8) -> Bool = { $2 > 180 && $0 < 100 && $1 < 100 }
    for body in ["Card([TextContent(\"Note\")],VARIANT)", "MarkDownRenderer(\"Note\",VARIANT)"] {
      let sunk = try raster("root=" + body.replacingOccurrences(of: "VARIANT", with: "\"sunk\""), theme: theme)
      let card = try raster("root=" + body.replacingOccurrences(of: "VARIANT", with: "\"card\""), theme: theme)
      XCTAssertEqual(sunk.count(red), 0)
      XCTAssertGreaterThan(card.count(red), 100, "The normal card is the visible-border positive control")
    }
    let form = "Form(\"f\",Buttons([]),[FormControl(\"Field\",Input(\"x\",\"Value\"))])"
    var presentation = OpenUIPresentation()
    presentation.formShowsCardSurface = false
    let nested = try raster("root=Card([\(form)],\"sunk\")", theme: theme, presentation: presentation)
    XCTAssertEqual(nested.count(red), 0)
    XCTAssertGreaterThan(nested.count(blue), 50, "Removing the content border must not erase editable field boundaries")
  }

  @MainActor func testFormSharesCardSurfaceAndSupportsExplicitHostOptOut() throws {
    var theme = OpenUITheme()
    theme.borderDefault = Color(red: 1, green: 0, blue: 0)
    theme.borderInteractive = Color(red: 0, green: 0, blue: 1)
    let form = "Form(\"f\",Buttons([]),[FormControl(\"Field\",Input(\"x\",\"Value\"))])"
    var plain = OpenUIPresentation(); plain.formShowsCardSurface = false
    let automatic = try raster("root=" + form, theme: theme)
    let composed = try raster("root=Card([\(form)],\"card\")", theme: theme, presentation: plain)
    XCTAssertEqual(automatic.width, composed.width)
    XCTAssertEqual(automatic.height, composed.height)
    XCTAssertEqual(automatic.pixels, composed.pixels, "Form must reuse Card geometry and paint rather than invent a second surface")
    let unframed = try raster("root=" + form, theme: theme, presentation: plain)
    let red: (UInt8, UInt8, UInt8) -> Bool = { $0 > 180 && $1 < 100 && $2 < 100 }
    XCTAssertGreaterThan(automatic.count(red), 100)
    XCTAssertEqual(unframed.count(red), 0)
    XCTAssertGreaterThan(automatic.height, unframed.height)
  }

  @MainActor func testNeutralIconAliasesRenderIdenticallyAndStatusVariantsKeepTheSameGeometry() throws {
    func source(_ variant: String) -> String {
      "root=IconText(Icon(\"map-pin\"),\"\(variant)\",\"m\",\"Same title\",\"Same details\",true)"
    }
    let neutral = try raster(source("neutral"))
    for variant in ["filled", "soft"] {
      let alias = try raster(source(variant))
      XCTAssertEqual(alias.width, neutral.width)
      XCTAssertEqual(alias.height, neutral.height)
      XCTAssertEqual(alias.pixels, neutral.pixels, "Aliases must not shift copy or add a different plate")
    }
    for variant in ["info", "success", "warning", "danger", "inverted"] {
      let status = try raster(source(variant))
      XCTAssertEqual(status.width, neutral.width)
      XCTAssertEqual(status.height, neutral.height)
    }
    let inverted = NativeIconTextStyle(variant: "inverted", theme: .init())
    XCTAssertNotEqual(inverted.background, .clear, "Inverted glyphs keep their contrasting surface")
  }

  /// Measure the painted surface independently of the invisible hit target.
  /// A 44pt target reproduces iOS's sizing feedback in the mounted macOS renderer.
  @MainActor func testButtonPaintDoesNotGrowWhenWrappedInRowOrColumn() throws {
    var presentation = OpenUIPresentation()
    presentation.minimumControlTargetSize = 44
    var theme = OpenUITheme()
    theme.interactiveAccentDefault = Color(red: 0, green: 0, blue: 1)
    theme.interactiveAccentDisabled = Color(red: 0, green: 0, blue: 1)
    func bounds(_ source: String, width: CGFloat = 320) throws -> CGRect {
      let image = try raster(source, theme: theme, presentation: presentation, width: width)
      var minX = image.width, minY = image.height, maxX = -1, maxY = -1
      for y in 0..<image.height {
        for x in 0..<image.width {
          let i = (y * image.width + x) * 4
          if image.pixels[i] < 50 && image.pixels[i + 1] < 80 && image.pixels[i + 2] > 180 {
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x); maxY = max(maxY, y)
          }
        }
      }
      XCTAssertGreaterThan(maxX, minX)
      return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
    for size in ["extra-small", "small", "medium", "large"] {
      let button = "Button(\"Details\",@OpenUrl(\"https://example.com\"),\"primary\",\"normal\",\"\(size)\")"
      let direct = try bounds("root=" + button)
      let row = try bounds("root=Buttons([\(button)],\"row\")")
      let column = try bounds("root=Buttons([\(button)],\"column\")")
      XCTAssertEqual(row.height, direct.height, accuracy: 1, "\(size): row must not paint its hit-target height")
      XCTAssertEqual(column.height, direct.height, accuracy: 1, "\(size): width fill must not change height")
      XCTAssertGreaterThan(column.width, direct.width + 40, "Column buttons still fill available width")
      XCTAssertGreaterThanOrEqual(try height("root=" + button, width: 320, presentation: presentation), 44)
    }
    let short = "Button(\"Details\",@OpenUrl(\"https://example.com\"),\"primary\",\"normal\",\"small\")"
    let long = "Button(\"Read the full details before continuing to the next step\",@OpenUrl(\"https://example.com\"),\"primary\",\"normal\",\"small\")"
    // Only the first surface is blue; the taller peer uses the destructive palette.
    let tallerPeer = "Button(\"Continue\\nnext step\",@OpenUrl(\"https://example.com\"),\"primary\",\"destructive\",\"large\")"
    XCTAssertEqual(try bounds("root=Buttons([\(short),\(tallerPeer)],\"row\")").height,
      try bounds("root=" + short).height, accuracy: 1,
      "A mixed-size, multiline peer must not enlarge the short button's painted surface")
    let directLong = try bounds("root=" + long, width: 140)
    XCTAssertGreaterThan(directLong.height, try bounds("root=" + short, width: 140).height)
    XCTAssertEqual(try bounds("root=Buttons([\(long)],\"row\")", width: 140).height,
      directLong.height, accuracy: 1, "Long text grows naturally rather than being clipped to a fixed height")
  }

  @MainActor func testMetadataTagsStayLighterThanActionsAndLongLabelsRemainUnbounded() throws {
    let tag = try height("root=Tag(\"Details\",null,\"md\",\"neutral\")", width: 240)
    let action = try height("root=Button(\"Details\",null,\"secondary\",\"normal\",\"medium\")", width: 240)
    XCTAssertLessThan(tag, action - 3)
    let long = String(repeating: "完整信息标签 ", count: 10)
    XCTAssertGreaterThan(try height("root=Tag(\(jsonStringLiteral(long)),null,\"md\",\"neutral\")", width: 180), tag * 2)
    let followup = try height("root=FollowUpBlock([FollowUpItem(\"Continue\")])", width: 240)
    XCTAssertGreaterThanOrEqual(followup, OpenUIPresentation().minimumControlTargetSize)
  }

  @MainActor func testUnavailableAndLoadedMediaKeepTheSameFrameIncludingLargeText() {
    _ = NSApplication.shared
    for size in [DynamicTypeSize.large, .accessibility2] {
      for width: CGFloat in [180, 320] {
        func dimensions(_ cached: Image?, sourceReady: Bool = true) -> CGSize {
          NSHostingView(rootView: NativeRemoteImage(src: nil, alt: "Object", layout: .aspect(16 / 9), cachedImage: cached)
            .environment(\.openUIMediaSourceReady, sourceReady).dynamicTypeSize(size)
            .frame(width: width)).fittingSize
        }
        let empty = dimensions(nil)
        XCTAssertEqual(empty.width, width, accuracy: 1)
        XCTAssertEqual(empty.height, width * 9 / 16, accuracy: 1)
        XCTAssertEqual(dimensions(Image(systemName: "photo")), empty)
        XCTAssertEqual(dimensions(nil, sourceReady: false), empty)
      }
    }
  }
  #endif
}
