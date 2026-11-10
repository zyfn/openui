import SwiftUI

/// Shared feedback timing. Views still honor the nearest Reduce Motion setting.
public struct OpenUIMotion {
    public var pressDuration: Double = 0.12
    public var pressedOpacity: Double = 0.92
    public var pressedScale: CGFloat = 0.985
    public var pagingResponse: Double = 0.32
    public var pagingDamping: Double = 0.86
    public var loadingShimmerDuration: Double = 1.6
    public var loadingIndicatorDelay: Double = 0.2
    public var mediaRevealDuration: Double = 0.18
    var loadingDelayNanoseconds: UInt64 {
        let seconds = loadingIndicatorDelay.isFinite ? max(0, loadingIndicatorDelay) : 0.2
        return UInt64(min(seconds * 1_000_000_000, Double(UInt64.max / 2)))
    }
    var loadingCycle: Double {
        loadingShimmerDuration.isFinite && loadingShimmerDuration > 0 ? loadingShimmerDuration : 1.6
    }
    public init() {}
}

