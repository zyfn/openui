import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Native system colors adapt to platform appearance. Series keep their source
/// index as data streams or a legend filters entries; no count-based recoloring.
enum NativeChartPalette {
  struct Swatch: Equatable {
    let color: Color
  }
  #if os(iOS)
  private static let base: [Color] = [UIColor.systemBlue, .systemOrange, .systemGreen,
    .systemPurple, .systemPink, .systemTeal, .systemIndigo, .systemCyan].map { Color(uiColor: $0) }
  #else
  private static let base: [Color] = [NSColor.systemBlue, .systemOrange, .systemGreen,
    .systemPurple, .systemPink, .systemTeal, .systemIndigo, .systemCyan].map { Color(nsColor: $0) }
  #endif

  static func swatches(count: Int) -> [Swatch] {
    (0..<max(1, count)).map { Swatch(color: base[$0 % base.count]) }
  }
}
