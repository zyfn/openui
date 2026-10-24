import SwiftUI

/// Shared visual roles, expressed as scalable system fonts. They are renderer
/// values rather than additional language fields or content-classification rules.
public struct OpenUITypography {
    public var display: Font = .title.weight(.semibold)
    public var title: Font = .title3.weight(.semibold)
    public var heading: Font = .headline.weight(.semibold)
    public var body: Font = .body
    public var detail: Font = .subheadline
    public var caption: Font = .caption
    public var metric: Font = .title.weight(.semibold).monospacedDigit()
    public var actionCompact: Font = .footnote.weight(.medium)
    public var actionRegular: Font = .subheadline.weight(.semibold)
    public init() {}
}

/// Shared feedback timing. Views still honor the nearest Reduce Motion setting.
public struct OpenUIMotion {
    public var pressDuration: Double = 0.12
    public var pressedOpacity: Double = 0.82
    public var pressedScale: CGFloat = 0.985
    public var pagingResponse: Double = 0.32
    public var pagingDamping: Double = 0.86
    public init() {}
}

/// A surface draws its own shape but never changes content layout or semantics.
/// Plain/sunken surfaces opt out of both border and elevation.
struct NativeCardSurface: ViewModifier {
    let theme: OpenUITheme
    var fill: Color? = nil
    var bordered = true

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(fill ?? theme.controlSurface)
                    .shadow(color: .black.opacity(bordered ? theme.cardShadowOpacity : 0),
                            radius: theme.cardShadowRadius, y: theme.cardShadowY)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .strokeBorder(bordered ? theme.border : .clear, lineWidth: theme.cardBorderWidth)
                    .allowsHitTesting(false)
            }
    }
}
