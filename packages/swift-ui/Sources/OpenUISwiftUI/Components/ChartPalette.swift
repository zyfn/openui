import SwiftUI

/// Ordered categorical colors. Growing a chart adds colors without recoloring
/// existing series; filtering uses the original series indices.
enum NativeChartPalette {
  struct Swatch: Equatable {
    let light: UInt32
    let dark: UInt32
    var color: Color { NativeControlPalette.adaptive(light: light, dark: dark) }
  }

  private static let base: [Swatch] = [
    .init(light: 0x287D87, dark: 0x79BDC5), // mineral teal
    .init(light: 0xB36C53, dark: 0xE3A18A), // clay
    .init(light: 0x6171A1, dark: 0xA2AFE0), // slate indigo
    .init(light: 0x9B7D36, dark: 0xD9BA73), // ochre
    .init(light: 0x916B87, dark: 0xCEA4C3), // plum
    .init(light: 0x6B8157, dark: 0xACC795), // olive
    .init(light: 0x547F99, dark: 0x99BCD2), // steel blue
    .init(light: 0xAE6D82, dark: 0xDFA3B8), // dusty rose
  ]

  static func swatches(count: Int) -> [Swatch] {
    (0..<max(1, count)).map { index in
      if index < base.count { return base[index] }
      let hue = (0.43 + Double(index - base.count) * 0.61803398875)
        .truncatingRemainder(dividingBy: 1)
      return Swatch(light: rgb(hue: hue, saturation: 0.48, brightness: 0.62),
        dark: rgb(hue: hue, saturation: 0.32, brightness: 0.86))
    }
  }

  private static func rgb(hue: Double, saturation: Double, brightness: Double) -> UInt32 {
    let position = hue * 6
    let sector = Int(position)
    let fraction = position - Double(sector)
    let p = brightness * (1 - saturation)
    let q = brightness * (1 - saturation * fraction)
    let t = brightness * (1 - saturation * (1 - fraction))
    let channels: (Double, Double, Double)
    switch sector % 6 {
    case 0: channels = (brightness, t, p)
    case 1: channels = (q, brightness, p)
    case 2: channels = (p, brightness, t)
    case 3: channels = (p, q, brightness)
    case 4: channels = (t, p, brightness)
    default: channels = (brightness, p, q)
    }
    return UInt32((channels.0 * 255).rounded()) << 16
      | UInt32((channels.1 * 255).rounded()) << 8
      | UInt32((channels.2 * 255).rounded())
  }
}
