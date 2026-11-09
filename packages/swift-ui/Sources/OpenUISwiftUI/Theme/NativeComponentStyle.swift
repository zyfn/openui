import SwiftUI

/// Reading roles resolve layout defaults without rewriting a complete host font.
enum NativeTextRole {
    case display, section, title, body, detail, caption, control, metric, code

    var lineHeight: CGFloat {
        switch self {
        case .display, .control, .metric: return 1.25
        case .section: return 1.30
        case .title: return 1.35
        case .detail: return 1.45
        case .caption: return 1.40
        case .body, .code: return 1.50
        }
    }
}

/// Shared component relationships. Explicit Lang sizes and gaps remain authoritative.
struct NativeComponentStyle {
    let theme: OpenUIThemeValues
    var titleDetailGap: CGFloat { theme.space2xs }
    var objectInset: CGFloat { theme.spaceM }
    var panelInset: CGFloat { theme.spaceML }
    var footerGap: CGFloat { theme.spaceS }
    var contextGap: CGFloat { theme.spaceS }
    var optionRadius: CGFloat { theme.radius2xl }
    var surfaceBorder: Color { theme.borderDefault }
    var controlBorder: Color { theme.borderInteractive }
    var selectedBorder: Color { theme.interactiveAccentDefault }
    var selectedSurface: Color { theme.highlight }
    var disabledText: Color { theme.textNeutralTertiary }
}

extension OpenUIThemeValues {
    var componentStyle: NativeComponentStyle { NativeComponentStyle(theme: self) }
}

/// One shape instance survives state changes. Nil radius follows the actual label height.
struct NativeButtonShape: InsettableShape {
    let radius: CGFloat?
    var maximumRadius: CGFloat? = nil
    private var inset: CGFloat = 0

    init(radius: CGFloat?, maximumRadius: CGFloat? = nil) {
        self.radius = radius
        self.maximumRadius = maximumRadius
    }

    /// A tall, wrapped label must remain inside the painted surface at its insets.
    static func readableRadius(horizontal: CGFloat, vertical: CGFloat) -> CGFloat {
        let h = max(0, horizontal), v = max(0, vertical)
        return h + v + sqrt(2 * h * v)
    }

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: inset, dy: inset)
        let capsule = max(0, min(bounds.width, bounds.height) / 2)
        let limit = maximumRadius.flatMap { $0.isFinite ? max(0, $0 - inset) : nil } ?? capsule
        let resolved = radius.flatMap { $0.isFinite ? max(0, $0 - inset) : nil } ?? min(capsule, limit)
        return RoundedRectangle(cornerRadius: resolved, style: .continuous).path(in: bounds)
    }

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.inset += amount
        return copy
    }
}
