import Foundation

/// Native preview geometry. Normal photos retain their proportions. Extremely
/// tall assets fit inside a region no taller than an ordinary 2:3 portrait;
/// the bitmap itself is never stretched or cropped. A preview limit is a
/// presentation choice, not part of the component's language contract.
enum NativeMediaPreview {
  static func aspectRatio(sourceSize: CGSize?) -> CGFloat {
    guard let size = sourceSize, size.width.isFinite, size.height.isFinite,
      size.width > 0, size.height > 0 else { return 4 / 3 }
    let ratio = size.width / size.height
    guard ratio.isFinite, ratio > 0 else { return 4 / 3 }
    return max(2 / 3, ratio)
  }
}
