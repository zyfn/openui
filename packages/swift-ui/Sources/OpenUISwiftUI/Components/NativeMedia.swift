import Foundation
import ImageIO
import OpenUILang
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum NativeMediaStatus: Equatable { case loading, loaded, unavailable }
enum NativeMediaLayout {
  case cover, aspect(CGFloat), thumbnail(CGSize), fit, fill, intrinsic
}

/// A resource placeholder is not an alert. Copy is shown only when it fits;
/// the enclosing image retains its accessible unavailable status at every size.
struct NativeUnavailableMedia: View {
  let theme: OpenUIThemeValues
  @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 16

  var body: some View {
    GeometryReader { geometry in
      let side = min(glyphSize, max(0, min(geometry.size.width, geometry.size.height)))
      ViewThatFits(in: .vertical) {
        if geometry.size.width >= 160 {
          VStack(spacing: theme.spaceXs) {
            glyph(side)
            Text("Image unavailable", bundle: NativeControlResources.bundle)
              .nativeTextStyle(theme.textStyle(.supporting))
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, theme.spaceS)
          }.fixedSize(horizontal: false, vertical: true)
        }
        glyph(side)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func glyph(_ side: CGFloat) -> some View {
    Image(systemName: "photo").resizable().scaledToFit()
      .frame(width: side, height: side).foregroundStyle(theme.textNeutralSecondary)
  }
}

/// Completed media belongs to the presentation, rather than a transient layout
/// branch. A late grid/carousel argument may relocate an already loaded image.
@MainActor final class NativeMediaCache {
  @MainActor struct Entry {
    let image: Image
    let size: CGSize
    let cost: Int
    // Keep ObjectIdentifier(loader) valid for the lifetime of this entry.
    let resourceOwner: any OpenUIResourceLoading
    var wasPresented = false
    var decodedPixelSize: Int = .max
    func satisfies(_ requested: Int) -> Bool {
      decodedPixelSize >= requested || max(size.width, size.height) <= CGFloat(decodedPixelSize)
    }
  }
  private var entries: [NativeResourceRequestID: Entry] = [:]
  private var order: [NativeResourceRequestID] = []
  private struct DecodeKey: Hashable { let resource: NativeResourceRequestID; let pixelSize: Int }
  private var pending: [DecodeKey: Task<Entry, Error>] = [:]
  private let maximumCost = 32 * 1024 * 1024
  private(set) var generation = 0
  subscript(_ key: NativeResourceRequestID) -> Entry? { entries[key] }
  func markPresented(_ key: NativeResourceRequestID) { entries[key]?.wasPresented = true }
  func insert(_ entry: Entry, for key: NativeResourceRequestID) {
    guard entry.cost <= maximumCost else { return }
    if let current = entries[key], current.decodedPixelSize > entry.decodedPixelSize { return }
    entries[key] = entry
    order.removeAll { $0 == key }; order.append(key)
    while order.count > 8 || entries.values.reduce(0, { $0 + $1.cost }) > maximumCost {
      entries.removeValue(forKey: order.removeFirst())
    }
  }
  func resource(_ key: NativeResourceRequestID, loader: any OpenUIResourceLoading,
                targetPixelSize: Int? = nil) async throws -> Entry {
    let target = max(1, min(targetPixelSize ?? loader.resourceLimits.maximumImagePixelSize,
                           loader.resourceLimits.maximumImagePixelSize, 2816))
    if let value = entries[key], value.satisfies(target) { return value }
    let decodeKey = DecodeKey(resource: key, pixelSize: target)
    if let task = pending[decodeKey] { return try await task.value }
    guard let request = key.request else { throw URLError(.badURL) }
    let current = generation
    let scope = loader.authorizationScopeID
    let task = Task { @MainActor [weak self] in
      let entry = try await Self.load(request, loader: loader, targetPixelSize: target)
      try Task.checkCancellation()
      guard let self, self.generation == current,
        loader.authorizationScopeID == scope else { throw CancellationError() }
      self.insert(entry, for: key)
      return entry
    }
    pending[decodeKey] = task
    defer { if generation == current { pending[decodeKey] = nil } }
    return try await task.value
  }
  // Bound the complete image pipeline, not just the decode step: queued
  // compressed Data must not grow while a limited decoder is occupied.
  private static let imageAdmission = NativeResourceAdmission(maximum: 2)
  static func load(_ request: URLRequest, loader: any OpenUIResourceLoading,
                   targetPixelSize: Int? = nil) async throws -> Entry {
    try await imageAdmission.acquire()
    defer { Task { await imageAdmission.release() } }
    try Task.checkCancellation()
    let scope = loader.authorizationScopeID
    let data = try await loader.data(for: request)
    let entry = try await prepare(data, loader: loader, targetPixelSize: targetPixelSize)
    guard loader.authorizationScopeID == scope else { throw CancellationError() }
    return entry
  }
  static func prepare(_ data: Data, loader: any OpenUIResourceLoading,
                      targetPixelSize: Int? = nil) async throws -> Entry {
    let limits = loader.resourceLimits
    let target = max(1, min(targetPixelSize ?? limits.maximumImagePixelSize, limits.maximumImagePixelSize, 2816))
    let work = Task.detached(priority: .userInitiated) {
      try NativeImageDecoder.decode(data, maximumPixelSize: target, limits: limits)
    }
    let decoded = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
    try Task.checkCancellation()
    return entry(decoded, loader: loader)
  }
  /// Synchronous entry is retained for small fixtures and explicit native callers.
  /// Live resource consumers use prepare to keep decoding off the UI actor.
  static func decode(_ data: Data, loader: any OpenUIResourceLoading) throws -> Entry {
    entry(try NativeImageDecoder.decode(data, maximumPixelSize: loader.resourceLimits.maximumImagePixelSize,
      limits: loader.resourceLimits), loader: loader)
  }
  private static func entry(_ decoded: NativeImageDecoder.Pixels, loader: any OpenUIResourceLoading) -> Entry {
    Entry(image: Image(decorative: decoded.image, scale: 1), size: decoded.sourceSize,
      cost: decoded.image.bytesPerRow * decoded.image.height, resourceOwner: loader,
      decodedPixelSize: max(decoded.image.width, decoded.image.height))
  }
  func removeAll() {
    generation &+= 1
    pending.values.forEach { $0.cancel() }; pending.removeAll()
    entries.removeAll(); order.removeAll()
  }
}
/// ImageIO validates source dimensions before decoding and never eagerly expands
/// a full-resolution UIImage/NSImage for a thumbnail. The pixel object is immutable.
enum NativeImageDecoder {
  struct Pixels: @unchecked Sendable { let image: CGImage; let sourceSize: CGSize }
  static func decode(_ data: Data, maximumPixelSize: Int, limits: OpenUIResourceLimits) throws -> Pixels {
    try Task.checkCancellation()
    guard data.count <= max(1, limits.maximumResponseBytes),
      let source = CGImageSourceCreateWithData(data as CFData,
        [kCGImageSourceShouldCache: false] as CFDictionary),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
      width.isFinite, height.isFinite, width > 0, height > 0,
      width * height <= Double(max(1, limits.maximumImageSourcePixels)) else {
        throw URLError(.cannotDecodeContentData)
    }
    let target = max(1, min(maximumPixelSize, limits.maximumImagePixelSize, 2816))
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: target,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw URLError(.cannotDecodeContentData)
    }
    try Task.checkCancellation()
    guard image.height > 0, image.bytesPerRow <= (32 * 1024 * 1024) / image.height else {
      throw URLError(.dataLengthExceedsMaximum)
    }
    let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    let rotated = (5...8).contains(orientation)
    return Pixels(image: image, sourceSize: CGSize(width: rotated ? height : width, height: rotated ? width : height))
  }
}

private struct NativeMediaCacheKey: EnvironmentKey { static let defaultValue: NativeMediaCache? = nil }
private struct NativeMediaSourceKey: EnvironmentKey { static let defaultValue = true }
private struct NativeMediaTaskID: Hashable {
  let request: NativeResourceRequestID?
  let sourceReady: Bool
  let pixelSize: Int
}
extension EnvironmentValues {
  var openUIMediaSourceReady: Bool {
    get { self[NativeMediaSourceKey.self] }
    set { self[NativeMediaSourceKey.self] = newValue }
  }
  var openUIMediaCache: NativeMediaCache? {
    get { self[NativeMediaCacheKey.self] }
    set { self[NativeMediaCacheKey.self] = newValue }
  }
}

/// Shared native resource presentation. Resource states preserve the declared
/// media layout; network failures remain separate from language diagnostics.
struct NativeRemoteImage: View {
    @Environment(\.openUIPresentation) private var nativePresentation
    @Environment(\.displayScale) private var displayScale

  let src: String?
  var alt = ""
  var layout: NativeMediaLayout = .cover
  var showsFailureSymbol = true
  var cachedImage: Image?
  var attempt = 0
  var onStatus: ((NativeMediaStatus, Image?) -> Void)?
  var interactionEnabled = true
  var previewEnabled = true
  @State private var localRetry = NativeImageRetryState()
  @Environment(\.openUIMediaSourceReady) private var sourceReady
  @Environment(\.openUIStreamActive) private var streamActive
  @Environment(\.openUIMediaWidthReady) private var widthReady
  @State private var phase: AsyncImagePhase = .empty
  @State private var imageSize: CGSize?
  @State private var loadedRequest: NativeResourceRequestID?
  @State private var revealLoadedImage = true
  @Environment(\.openUIResourceContext) private var resources
  @Environment(\.openUITheme) private var theme
  @Environment(\.openUICardIsAction) private var cardIsAction
  @Environment(\.openUIMediaCache) private var mediaCache

  var body: some View {
    Group {
      // Each media role owns its frame before pixels arrive. A later parent
      // layout argument must not temporarily replace it with a small thumbnail.
      if !widthReady && needsResolvedWidth {
        NativePendingContent(loading: streamActive, message: "Loading image")
      } else if !sourceReady {
        placeholder(loading: streamActive).onAppear { onStatus?(streamActive ? .loading : .unavailable, nil) }
      } else if let cachedImage {
        picture(cachedImage, reveal: false).onAppear { onStatus?(.loaded, cachedImage) }
      } else if loadedRequest != requestID, let retained = mediaCache?[requestID] {
        picture(retained.image, retainedSize: retained.size, reveal: !retained.wasPresented)
          .onAppear { mediaCache?.markPresented(requestID); onStatus?(.loaded, retained.image) }
      } else if resources.request(for: src) != nil {
        Group {
          switch loadedRequest == requestID ? phase : .empty {
          case .success(let image): picture(image, reveal: revealLoadedImage).onAppear {
            mediaCache?.markPresented(requestID); onStatus?(.loaded, image)
          }
          case .empty: loading.onAppear { onStatus?(.loading, nil) }
          case .failure: unavailable.onAppear { onStatus?(.unavailable, nil) }
          @unknown default: unavailable.onAppear { onStatus?(.unavailable, nil) }
          }
        }
      } else {
        unavailable.onAppear { onStatus?(.unavailable, nil) }
      }
    }
    .modifier(NativeImageInteraction(source: src, image: displayedImage, alt: alt,
      enabled: interactionEnabled, previewEnabled: previewEnabled, failed: failed,
      retry: { localRetry.retry(baseRequestID) }))
    .task(id: NativeMediaTaskID(request: sourceReady ? requestID : nil, sourceReady: sourceReady, pixelSize: targetPixelSize)) {
      guard sourceReady, cachedImage == nil else { return }
      if let retained = mediaCache?[requestID], retained.satisfies(targetPixelSize) {
        // A mounted image owns its successful phase. The bounded presentation
        // cache can evict this entry while later cards are still arriving.
        loadedRequest = requestID
        imageSize = retained.size
        revealLoadedImage = !retained.wasPresented
        phase = .success(retained.image)
        return
      }
      if requestID.request == nil { onStatus?(.unavailable, nil) } else { await load() }
    }
  }
  private var displayedImage: Image? {
    if let cachedImage { return cachedImage }
    if loadedRequest == requestID, case .success(let image) = phase { return image }
    return mediaCache?[requestID]?.image
  }
  private var failed: Bool {
    guard sourceReady, requestID.request != nil, loadedRequest == requestID else { return false }
    if case .failure = phase { return true }; return false
  }
  private var baseRequestID: NativeResourceRequestID {
    .init(request: resources.request(for: src), loader: ObjectIdentifier(resources.loader), attempt: attempt, authorizationScope: resources.loader.authorizationScopeID)
  }
  private var requestID: NativeResourceRequestID {
    var request = resources.request(for: src)
    let currentAttempt = attempt + localRetry.attempt(for: baseRequestID)
    if currentAttempt > 0 { request?.cachePolicy = .reloadIgnoringLocalCacheData }
    return .init(request: request, loader: ObjectIdentifier(resources.loader), attempt: currentAttempt, authorizationScope: resources.loader.authorizationScopeID)
  }
  private var targetPixelSize: Int {
    let cap = max(1, resources.loader.resourceLimits.maximumImagePixelSize)
    if case .thumbnail(let size) = layout {
      let requested = max(size.width, size.height) * displayScale
      guard requested.isFinite else { return cap }
      return max(1, Int(min(CGFloat(cap), ceil(requested))))
    }
    return cap
  }
  private var needsResolvedWidth: Bool {
    if case .thumbnail = layout { return false }
    return true
  }
  @MainActor private func load() async {
    let id = requestID
    let generation = mediaCache?.generation
    guard let request = id.request else { return }
    loadedRequest = id; phase = .empty; imageSize = nil; revealLoadedImage = true
    do {
      let entry: NativeMediaCache.Entry
      if let mediaCache { entry = try await mediaCache.resource(id, loader: resources.loader, targetPixelSize: targetPixelSize) }
      else { entry = try await NativeMediaCache.load(request, loader: resources.loader, targetPixelSize: targetPixelSize) }
      try Task.checkCancellation()
      guard id == requestID, mediaCache?.generation == generation else { return }
      guard id == requestID else { return }
      imageSize = entry.size
      phase = .success(entry.image)
    } catch {
      guard !Task.isCancelled, id == requestID else { return }
      phase = .failure(error)
    }
  }
  private func picture(_ image: Image, retainedSize: CGSize? = nil, reveal: Bool = true) -> some View {
    Group {
      switch layout {
      case .intrinsic, .fit:
        canvas(sourceSize: retainedSize) { image.resizable().scaledToFit().modifier(NativeMediaReveal(enabled: reveal)) }
      default:
        canvas(sourceSize: retainedSize) { image.resizable().scaledToFill().modifier(NativeMediaReveal(enabled: reveal)) }
      }
    }
    .accessibilityElement(children: .ignore).accessibilityLabel(alt)
    .accessibilityAddTraits(.isImage).accessibilityHidden(alt.isEmpty && !interactionEnabled)
  }
  private var loading: some View { placeholder(loading: true) }
  private var unavailable: some View { placeholder(loading: false) }
  private func placeholder(loading: Bool) -> some View {
    canvas {
      if loading {
        NativeLoadingSurface(showsMediaSymbol: true)
      } else {
        ZStack {
          theme.sunk
          if showsFailureSymbol {
            NativeUnavailableMedia(theme: theme)
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      alt.isEmpty
        ? Text(loading ? "Loading image" : "Image unavailable", bundle: NativeControlResources.bundle) : Text(alt)
    )
    .accessibilityValue(Text(loading ? "Loading image" : "Image unavailable", bundle: NativeControlResources.bundle))
    .accessibilityAddTraits(.isImage)
    .accessibilityIdentifier(loading ? "openui.media.loading" : "openui.media.unavailable")
  }
  // Document illustrations retain their source proportions; photo previews
  // use the same declared role in every resource state.
  @ViewBuilder private func canvas<Content: View>(sourceSize: CGSize? = nil,
    @ViewBuilder _ content: () -> Content) -> some View {
    let surface = Color.clear.overlay { content().accessibilityHidden(true) }.clipped().contentShape(Rectangle())
    switch layout {
    case .cover:
      surface.aspectRatio(nativePresentation.coverAspectRatio, contentMode: .fit).fixedSize(horizontal: false, vertical: true)
    case .aspect(let ratio):
      surface.aspectRatio(ratio, contentMode: .fit).fixedSize(horizontal: false, vertical: true)
    case .thumbnail(let size): surface.frame(width: size.width, height: size.height)
    case .fit, .fill: surface.frame(maxWidth: .infinity, maxHeight: .infinity)
    case .intrinsic:
      surface.aspectRatio(NativeMediaPreview.aspectRatio(sourceSize: sourceSize ?? imageSize), contentMode: .fit)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct NativeGalleryResourceID: Hashable {
  let itemID: String
  let source: String?
  let request: NativeResourceRequestID
}

private struct NativeGalleryImage: Identifiable {
  let id: String
  let index: Int
  let src: String?
  let alt: String
  let details: String?
  let requestID: NativeResourceRequestID
  let sourceReady: Bool
  var key: NativeGalleryResourceID { .init(itemID: id, source: src, request: requestID) }
}

/// Small galleries are measured synchronously at their actual container width.
/// Columns never outnumber the supplied images, so sparse galleries fill the row.
struct NativeGalleryGridLayout: Layout {
  let minimumWidth: CGFloat
  let gap: CGFloat
  var maximumColumns: Int?
  var layoutCount: Int? = nil

  private func frames(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (CGFloat, [CGRect]) {
    let width = proposal.width.flatMap { $0.isFinite ? max(1, $0) : nil } ?? max(1, minimumWidth)
    guard !subviews.isEmpty else { return (width, []) }
    let count = max(subviews.count, layoutCount ?? subviews.count)
    let columns = min(count, maximumColumns ?? count,
      max(1, Int((width + gap) / max(1, minimumWidth + gap))))
    let tileWidth = max(1, (width - gap * CGFloat(columns - 1)) / CGFloat(columns))
    let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: tileWidth, height: nil)) }
    var result: [CGRect] = []
    var y: CGFloat = 0
    for start in stride(from: 0, to: subviews.count, by: columns) {
      let end = min(start + columns, subviews.count)
      let rowHeight = sizes[start..<end].map(\.height).max() ?? 0
      for index in start..<end {
        result.append(CGRect(x: CGFloat(index - start) * (tileWidth + gap), y: y,
          width: tileWidth, height: sizes[index].height))
      }
      y += rowHeight + gap
    }
    return (width, result)
  }
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let (width, frames) = frames(proposal, subviews)
    return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
  }
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let (_, frames) = frames(ProposedViewSize(width: bounds.width, height: nil), subviews)
    for (view, frame) in zip(subviews, frames) {
      view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: nil))
    }
  }
}

struct NativeImageGallery: View {
  let context: OpenUIComponentContext
  @Environment(\.openUIResourceContext) private var resources
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var readingScale: CGFloat = 1
  @State private var phases: [NativeGalleryResourceID: NativeMediaStatus] = [:]
  @State private var pictures: [NativeGalleryResourceID: Image] = [:]
  @State private var selected: NativeGalleryResourceID?
  @State private var preview = false
  @State private var retries: [String: Int] = [:]
  // Keep a compact inline preview. Any image opens the complete gallery, so
  // additional photos remain reachable without a separate Show All control.
  private let previewLimit = 5
  @State private var stableImages: [NativeGalleryImage]?
  private var images: [NativeGalleryImage] {
    if context.hasPendingData || context.hasDataFailure, let stableImages { return stableImages }
    return currentImages
  }
  private var currentImages: [NativeGalleryImage] {
    let children = context.presentationChildren("images")
    let source = context.element.sourceReadiness["images"]
    let mapped = source.valueIndices.map { $0.compactMap { $0 } == Array(children.indices) } ?? false
    let aligned = source.complete || source.expectedCount == children.count || mapped
    return children.enumerated().map { index, child in
      let attempt = retries[child.id, default: 0]
      var request = resources.request(for: NativeValue.string(child.value, "src"))
      if attempt > 0 { request?.cachePolicy = .reloadIgnoringLocalCacheData }
      return NativeGalleryImage(id: child.id, index: index,
        src: NativeValue.string(child.value, "src"), alt: NativeValue.string(child.value, "alt") ?? "",
        details: NativeValue.string(child.value, "details"),
        requestID: .init(request: request, loader: ObjectIdentifier(resources.loader), attempt: attempt, authorizationScope: resources.loader.authorizationScopeID),
        sourceReady: {
          if case .element(let image) = child.value { return image.sourceReadiness["src"].complete }
          guard aligned else { return false }
          return source[index]["src"].complete
        }())
    }
  }
  private var visible: [NativeGalleryImage] { Array(images.prefix(previewLimit)) }
  private var gridReady: Bool {
    if stableImages != nil && (context.hasPendingData || context.hasDataFailure) { return true }
    return NativeLayoutContract.collectionShapeReady(context.element.sourceReadiness["images"], count: images.count)
  }
  private var layoutCount: Int? {
    let source = context.element.sourceReadiness["images"]
    return !source.complete && source.closed ? source.expectedCount.map { min(previewLimit, $0) } : nil
  }
  private func rememberImages() {
    if gridReady && !context.hasPendingData && !context.hasDataFailure { stableImages = currentImages }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: context.theme.spaceM) {
      if !gridReady || (visible.isEmpty && (context.hasPendingData || (context.isStreaming && !context.element.isSourceComplete))) {
        NativePendingContent(loading: !context.hasDataFailure && (context.isStreaming || context.hasPendingData), message: "Loading image")
      } else if !visible.isEmpty {
        NativeGalleryGridLayout(minimumWidth: max(context.presentation.thumbnailSize,
            context.presentation.minimumCompactCardWidth * readingScale),
          gap: context.theme.spaceM, maximumColumns: typeSize.isAccessibilitySize ? 1 : nil, layoutCount: layoutCount) {
          ForEach(visible) { image in
            VStack(alignment: .leading, spacing: context.theme.spacing("xs")) {
              Button {
                guard context.canActivate else { return }
                if phases[image.key] == .unavailable { retry(image) }
                else { selected = image.key; preview = true }
              } label: {
                NativeRemoteImage(
                  src: image.src, alt: image.alt, layout: .cover,
                  cachedImage: pictures[image.key], attempt: image.requestID.attempt,
                  onStatus: { record($0, image: $1, for: image.key) }, interactionEnabled: false
                )
                .environment(\.openUIMediaSourceReady, image.sourceReady)
                .background(context.theme.sunk)
                .clipShape(RoundedRectangle(cornerRadius: context.theme.radiusM, style: .continuous))
              }
              .buttonStyle(.plain).disabled(!context.canInteract || (!image.sourceReady) || (pictures[image.key] == nil && phases[image.key] != .unavailable))
              .accessibilityLabel(image.alt.isEmpty ? Text("View image", bundle: NativeControlResources.bundle) : Text(image.alt))
              .accessibilityValue(
                phases[image.key] == .unavailable
                  ? Text("Image unavailable", bundle: NativeControlResources.bundle)
                  : pictures[image.key] == nil ? Text("Loading image", bundle: NativeControlResources.bundle) : Text("")
              )
              .accessibilityIdentifier("openui.gallery.image.\(image.index)")
              if let details = image.details { Text(details).nativeTextStyle(context.theme.textStyle(.supporting)) }
            }
          }
        }
      }
    }
    .accessibilityElement(children: .contain).accessibilityIdentifier("openui.gallery")
    .onAppear(perform: rememberImages)
    .onChange(of: ObjectIdentifier(context.element)) { _ in rememberImages() }
    .onChange(of: context.hasPendingData) { _ in rememberImages() }
    .sheet(isPresented: $preview) {
      NativeGalleryPreview(images: images, selected: $selected, pictures: pictures, phases: phases, record: record, retry: retry)
    }
    .onChange(of: images.map(\.key)) { keys in
      let current = Set(keys)
      phases = phases.filter { current.contains($0.key) }
      pictures = pictures.filter { current.contains($0.key) }
      if selected.map(current.contains) != true { preview = false; selected = nil }
    }
  }
  private func retry(_ image: NativeGalleryImage) {
    retries[image.id, default: 0] += 1
    if selected == image.key { selected = currentImages.first(where: { $0.id == image.id })?.key }
  }
  private func record(_ phase: NativeMediaStatus, image: Image?, for key: NativeGalleryResourceID) {
    guard images.contains(where: { $0.key == key }) else { return }
    if let image, pictures[key] == nil { pictures[key] = image }
    if phases[key] != .loaded && phases[key] != phase { phases[key] = phase }
  }
}

private struct NativeGalleryPreview: View {
    @Environment(\.openUIPresentation) private var nativePresentation

  let images: [NativeGalleryImage]
  @Binding var selected: NativeGalleryResourceID?
  let pictures: [NativeGalleryResourceID: Image]
  let phases: [NativeGalleryResourceID: NativeMediaStatus]
  let record: (NativeMediaStatus, Image?, NativeGalleryResourceID) -> Void
  let retry: (NativeGalleryImage) -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openUITheme) private var theme
  @State private var zoomed = false
  private var image: NativeGalleryImage? { images.first { $0.key == selected } }
  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing("m")) {
      NativeImagePreviewHeader(position: image?.index, count: images.count,
        closeIdentifier: "openui.gallery.close", close: { dismiss() })
      if let image {
        GeometryReader { geometry in
          NativePager(ids: images.map(\.key), selection: Binding(
            get: { selected ?? image.key }, set: { selected = $0; zoomed = false }),
            enabled: !zoomed, identifier: "openui.gallery.preview", supportsAdjustment: false) { key in
            if let item = images.first(where: { $0.key == key }) {
              NativeRemoteImage(src: item.src, alt: item.alt, layout: .fit,
                cachedImage: pictures[item.key], attempt: item.requestID.attempt,
                onStatus: { record($0, $1, item.key) }, previewEnabled: false)
                .modifier(NativeImageZoom(resetID: selected, zoomChanged: { value in
                  if selected == item.key { zoomed = value }
                }))
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
          }
        }.accessibilityIdentifier("openui.gallery.preview.image")
          .accessibilityHint(Text(zoomed ? "Drag to move image" : "Swipe to change image", bundle: NativeControlResources.bundle))
        if !image.alt.isEmpty { Text(image.alt).nativeTextStyle(theme.textStyle(.body)) }
        if let details = image.details, details != image.alt { Text(details).nativeTextStyle(theme.textStyle(.supporting)) }
      }
      ScrollViewReader { reader in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: theme.spaceM) {
            ForEach(images) { image in
              Button { if phases[image.key] == .unavailable { retry(image) } else { selected = image.key; zoomed = false } } label: {
                NativeRemoteImage(src: image.src, alt: image.alt,
                  layout: .thumbnail(CGSize(width: nativePresentation.compactThumbnailSize,
                    height: nativePresentation.compactThumbnailSize / nativePresentation.coverAspectRatio)),
                  cachedImage: pictures[image.key], attempt: image.requestID.attempt, onStatus: { record($0, $1, image.key) }, interactionEnabled: false)
                  .clipShape(RoundedRectangle(cornerRadius: theme.radiusM, style: .continuous))
                  .overlay(RoundedRectangle(cornerRadius: theme.radiusM, style: .continuous).strokeBorder(selected == image.key ? theme.interactiveAccentDefault : .clear, lineWidth: 2))
              }.buttonStyle(.plain)
                .accessibilityLabel(image.alt.isEmpty ? Text("View image", bundle: NativeControlResources.bundle) : Text(image.alt))
                .accessibilityIdentifier("openui.gallery.thumbnail.\(image.index)")
                .id(image.key)
            }
          }
        }
        .onAppear { if let selected { reader.scrollTo(selected, anchor: .center) } }
        .onChange(of: selected) { key in
          zoomed = false
          if let key { reader.scrollTo(key, anchor: .center) }
        }
      }
    }
    .padding(theme.spaceML).frame(idealWidth: 720, idealHeight: 640)
    .accessibilityElement(children: .contain).accessibilityIdentifier("openui.gallery.preview")
  }
}

struct NativeImageRetryState {
  private var key: NativeResourceRequestID?
  private var count = 0
  func attempt(for request: NativeResourceRequestID) -> Int { key == request ? count : 0 }
  mutating func retry(_ request: NativeResourceRequestID) {
    if key != request { key = request; count = 0 }
    count += 1
  }
}
