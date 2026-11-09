import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// One font description for both native text and Markdown/KaTeX text. Scaling
/// belongs to the receiving view's environment, never a process-wide screen.
public struct OpenUIFont: Equatable {
    public var size: CGFloat
    public var weight: Font.Weight
    public var family: String?
    public var design: Font.Design
    /// Native additional line spacing in em. Explicit leading overrides reading-role defaults.
    /// Low-level metrics without a resolved role retain a 0.20 fallback.
    public var lineSpacing: CGFloat?
    /// Desired baseline line height as a multiple of font size. Native glyph metrics
    /// are the minimum; a smaller value never clips text. Takes precedence over lineSpacing.
    public var lineHeight: CGFloat?
    /// Tracking in em, applied consistently to native and Markdown text.
    public var letterSpacing: CGFloat = 0
    public var monospacedDigits = false
    public init(size: CGFloat, weight: Font.Weight = .regular,
                family: String? = nil, design: Font.Design = .default, lineSpacing: CGFloat? = nil, lineHeight: CGFloat? = nil, letterSpacing: CGFloat = 0) {
        self.size = size; self.weight = weight; self.family = family; self.design = design
        self.lineSpacing = lineSpacing; self.lineHeight = lineHeight; self.letterSpacing = letterSpacing
    }
    public func weight(_ value: Font.Weight) -> Self { var copy = self; copy.weight = value; return copy }
    public func monospacedDigit() -> Self { var copy = self; copy.monospacedDigits = true; return copy }
    func resolved(for role: NativeTextRole) -> Self {
        guard lineHeight == nil, lineSpacing == nil else { return self }
        var copy = self
        copy.lineHeight = role.lineHeight
        return copy
    }
    func measuredLineHeight(scale: CGFloat = 1) -> CGFloat {
        nativeLineHeight * scale + additionalLineSpacing(scale: scale)
    }
    func additionalLineSpacing(scale: CGFloat = 1) -> CGFloat {
        guard let lineHeight, lineHeight.isFinite, lineHeight > 0 else {
            return size * (lineSpacing ?? 0.20) * scale
        }
        return max(0, size * lineHeight - nativeLineHeight) * scale
    }
    private var nativeLineHeight: CGFloat {
        #if canImport(UIKit)
        let weight: UIFont.Weight = self.weight == .bold ? .bold : self.weight == .semibold ? .semibold
            : self.weight == .medium ? .medium : self.weight == .light ? .light : self.weight == .black ? .black
            : self.weight == .heavy ? .heavy : self.weight == .thin ? .thin : self.weight == .ultraLight ? .ultraLight : .regular
        var font = family.flatMap { UIFont(name: $0, size: size) }
            ?? (design == .monospaced ? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
                : UIFont.systemFont(ofSize: size, weight: weight))
        if family == nil, design == .serif || design == .rounded,
           let descriptor = font.fontDescriptor.withDesign(design == .serif ? .serif : .rounded) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        return font.lineHeight
        #elseif canImport(AppKit)
        let weight: NSFont.Weight = self.weight == .bold ? .bold : self.weight == .semibold ? .semibold
            : self.weight == .medium ? .medium : self.weight == .light ? .light : self.weight == .black ? .black
            : self.weight == .heavy ? .heavy : self.weight == .thin ? .thin : self.weight == .ultraLight ? .ultraLight : .regular
        var font = family.flatMap { NSFont(name: $0, size: size) }
            ?? (design == .monospaced ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
                : NSFont.systemFont(ofSize: size, weight: weight))
        if family == nil, design == .serif || design == .rounded,
           let descriptor = font.fontDescriptor.withDesign(design == .serif ? .serif : .rounded),
           let designed = NSFont(descriptor: descriptor, size: size) { font = designed }
        return font.ascender - font.descender + font.leading
        #else
        return size * 1.2
        #endif
    }
    public func nativeFont(scale: CGFloat = 1) -> Font {
        let font = family.map { Font.custom($0, fixedSize: size * scale).weight(weight) }
            ?? .system(size: size * scale, weight: weight, design: design)
        return monospacedDigits ? font.monospacedDigit() : font
    }
}

