import Foundation
import OpenUILang
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum NativeMediaStatus: Equatable { case loading, loaded, unavailable }
enum NativeMediaLayout {
  case aspect(CGFloat), thumbnail(CGSize), fit, fill, intrinsic, stretch
}

/// Shared native resource presentation. Resource states preserve the declared
/// media layout; network failures remain separate from language diagnostics.
struct NativeRemoteImage: View {
  let src: String?
  var alt = ""
  var layout: NativeMediaLayout = .aspect(4 / 3)
  var cachedImage: Image?
  var attempt = 0
  var onStatus: ((NativeMediaStatus, Image?) -> Void)?
  @State private var phase: AsyncImagePhase = .empty
  @State private var imageSize: CGSize?
  @State private var loadedRequest: NativeResourceRequestID?
  @Environment(\.openUIResourceContext) private var resources
  @Environment(\.openUITheme) private var theme
  @Environment(\.openUICardIsAction) private var cardIsAction

  var body: some View {
    Group {
      if let cachedImage {
        picture(cachedImage).onAppear { onStatus?(.loaded, cachedImage) }
      } else if resources.request(for: src) != nil {
        Group {
          switch loadedRequest == requestID ? phase : .empty {
          case .success(let image): picture(image).onAppear { onStatus?(.loaded, image) }
          case .empty: loading.onAppear { onStatus?(.loading, nil) }
          case .failure: unavailable.onAppear { onStatus?(.unavailable, nil) }
          @unknown default: unavailable.onAppear { onStatus?(.unavailable, nil) }
          }
        }
      } else {
        unavailable.onAppear { onStatus?(.unavailable, nil) }
      }
    }
    .task(id: requestID) {
      guard cachedImage == nil else { return }
      if requestID.request == nil { onStatus?(.unavailable, nil) } else { await load() }
    }
  }
  private var requestID: NativeResourceRequestID {
    .init(request: resources.request(for: src), loader: ObjectIdentifier(resources.loader), attempt: attempt)
  }
  @MainActor private func load() async {
    let id = requestID
    guard let request = id.request else { return }
    loadedRequest = id; phase = .empty; imageSize = nil
    do {
      let data = try await resources.loader.data(for: request)
      try Task.checkCancellation()
      #if os(iOS)
      guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
      let result = Image(uiImage: image)
      #else
      guard let image = NSImage(data: data) else { throw URLError(.cannotDecodeContentData) }
      let result = Image(nsImage: image)
      #endif
      guard id == requestID else { return }
      imageSize = image.size
      phase = .success(result)
    } catch {
      guard !Task.isCancelled, id == requestID else { return }
      phase = .failure(error)
    }
  }
  private func picture(_ image: Image) -> some View {
    Group {
      if case .intrinsic = layout {
        canvas { image.resizable().scaledToFit() }
      } else {
        canvas {
          if case .fit = layout { image.resizable().scaledToFit() }
          else { image.resizable().scaledToFill() }
        }
      }
    }
    .accessibilityElement(children: .ignore).accessibilityLabel(alt)
    .accessibilityAddTraits(.isImage).accessibilityHidden(alt.isEmpty)
  }
  private var loading: some View { placeholder(loading: true) }
  private var unavailable: some View { placeholder(loading: false) }
  private func placeholder(loading: Bool) -> some View {
    canvas {
      ZStack {
        theme.surface
        if loading {
          ProgressView().controlSize(.small).tint(theme.secondary)
        } else {
          Image(systemName: "photo").font(.body).foregroundStyle(theme.secondary.opacity(0.55))
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
  // Source proportions determine ordinary image height. Explicitly stretched
  // images receive their bounds from the parent instead.
  private var previewAspectRatio: CGFloat {
    NativeMediaPreview.aspectRatio(sourceSize: imageSize)
  }
  @ViewBuilder private func canvas<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    let surface = Color.clear.overlay { content().accessibilityHidden(true) }.clipped().contentShape(Rectangle())
    switch layout {
    case .aspect(let ratio):
      surface.aspectRatio(ratio, contentMode: .fit).fixedSize(horizontal: false, vertical: true)
    case .thumbnail(let size): surface.frame(width: size.width, height: size.height)
    case .fit, .fill: surface.frame(maxWidth: .infinity, maxHeight: .infinity)
    case .intrinsic:
      surface.aspectRatio(previewAspectRatio, contentMode: .fit).fixedSize(horizontal: false, vertical: true)
    case .stretch:
      NativeStretchMediaLayout(aspectRatio: previewAspectRatio) { surface }
    }
  }
}

/// Keep a natural measurement until the parent supplies both dimensions. A
/// stretched row can then crop the image into its measured cross-axis extent
/// without making that row collapse or relying on a fixed image/text ratio.
private struct NativeStretchMediaLayout: Layout {
  let aspectRatio: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let ideal = subviews.first?.sizeThatFits(.unspecified) ?? .zero
    let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? ideal.width
    let height = proposal.height.flatMap { $0.isFinite ? max(0, $0) : nil }
      ?? width / max(aspectRatio, .leastNonzeroMagnitude)
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
  }
}

private struct NativeOriginalImageLink: View {
  let src: String?
  @Environment(\.openURL) private var openURL
  @Environment(\.openUIResourceContext) private var resources
  var body: some View {
    if let url = resources.request(for: src)?.url {
      Button { openURL(url) } label: {
        Text("Open original image", bundle: NativeControlResources.bundle)
      }.buttonStyle(.plain).font(.caption).frame(minHeight: 44)
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
  var key: NativeGalleryResourceID { .init(itemID: id, source: src, request: requestID) }
}

struct NativeImageGallery: View {
  let context: OpenUIComponentContext
  @Environment(\.openUIResourceContext) private var resources
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var phases: [NativeGalleryResourceID: NativeMediaStatus] = [:]
  @State private var pictures: [NativeGalleryResourceID: Image] = [:]
  @State private var selected: NativeGalleryResourceID?
  @State private var preview = false
  @State private var diagnostics = false
  @State private var retries: [String: Int] = [:]
  // The pinned upstream ImageGallery previews five items, with Show All.
  private let previewLimit = 5
  private var images: [NativeGalleryImage] {
    context.children("images").enumerated().map { index, child in
      NativeGalleryImage(id: child.id, index: index,
        src: NativeValue.string(child.value, "src"), alt: NativeValue.string(child.value, "alt") ?? "",
        details: NativeValue.string(child.value, "details"),
        requestID: .init(request: resources.request(for: NativeValue.string(child.value, "src")),
          loader: ObjectIdentifier(resources.loader), attempt: retries[child.id, default: 0]))
    }
  }
  private var visible: [NativeGalleryImage] { Array(images.prefix(previewLimit)) }
  private var failed: [NativeGalleryImage] { images.filter { phases[$0.key] == .unavailable } }
  var body: some View {
    VStack(alignment: .leading, spacing: context.theme.contentSpacing) {
      if !visible.isEmpty {
        LazyVGrid(
          columns: typeSize.isAccessibilitySize
            ? [GridItem(.flexible(), alignment: .topLeading)]
            : [
              GridItem(
                .adaptive(minimum: context.theme.minimumCompactCardWidth), spacing: context.theme.contentSpacing,
                alignment: .topLeading)
            ],
          alignment: .leading, spacing: context.theme.contentSpacing) {
          ForEach(visible) { image in
            VStack(alignment: .leading, spacing: context.theme.spacing("xs")) {
              Button {
                selected = image.key; preview = true
              } label: {
                NativeRemoteImage(
                  src: image.src, alt: image.alt, layout: .aspect(4 / 3),
                  cachedImage: pictures[image.key], attempt: image.requestID.attempt,
                  onStatus: { record($0, image: $1, for: image.key) }
                )
                .clipShape(RoundedRectangle(cornerRadius: context.theme.mediaCornerRadius))
              }
              .buttonStyle(.plain).disabled(!context.canInteract || pictures[image.key] == nil)
              .accessibilityLabel(image.alt.isEmpty ? Text("View image", bundle: NativeControlResources.bundle) : Text(image.alt))
              .accessibilityValue(
                phases[image.key] == .unavailable
                  ? Text("Image unavailable", bundle: NativeControlResources.bundle)
                  : pictures[image.key] == nil ? Text("Loading image", bundle: NativeControlResources.bundle) : Text("")
              )
              .accessibilityIdentifier("openui.gallery.image.\(image.index)")
              if let details = image.details { Text(details).font(context.theme.typography.caption).foregroundStyle(context.theme.secondary) }
            }
          }
        }
      }
      if !images.isEmpty {
        HStack {
          if images.count > previewLimit {
            Button {
              if !images.contains(where: { $0.key == selected && pictures[$0.key] != nil }) {
                selected = images.first(where: { pictures[$0.key] != nil })?.key
              }
              preview = true
            } label: {
              Text("Show all photos", bundle: NativeControlResources.bundle)
            }
            .disabled(!context.canInteract).accessibilityIdentifier("openui.gallery.showAll")
          }
          Spacer(minLength: 0)
          Menu {
            if !failed.isEmpty {
              Button {
                for image in failed { retries[image.id, default: 0] += 1 }
              } label: {
                Text("Retry", bundle: NativeControlResources.bundle)
              }
              .accessibilityIdentifier("openui.gallery.retry")
            }
            Button {
              diagnostics = true
            } label: {
              Text("Image descriptions", bundle: NativeControlResources.bundle)
            }
            .accessibilityIdentifier("openui.gallery.details")
          } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44)
          }
          .accessibilityLabel(Text("Image descriptions", bundle: NativeControlResources.bundle))
          .accessibilityIdentifier("openui.gallery.options")
          .disabled(!context.canInteract)
        }.font(context.theme.typography.caption)
      }
    }
    .accessibilityElement(children: .contain).accessibilityIdentifier("openui.gallery")
    .sheet(isPresented: $preview) {
      NativeGalleryPreview(images: images, selected: $selected, pictures: pictures, phases: phases, record: record)
    }
    .sheet(isPresented: $diagnostics) {
      NavigationView {
        List(images) { image in
          VStack(alignment: .leading, spacing: 4) {
            Text(image.alt)
            if let details = image.details { Text(details).font(.caption) }
            if phases[image.key] == .unavailable {
              Text("Image unavailable", bundle: NativeControlResources.bundle).font(.caption)
            }
            NativeOriginalImageLink(src: image.src)
          }
        }
        .navigationTitle(Text("Image descriptions", bundle: NativeControlResources.bundle))
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button {
              diagnostics = false
            } label: {
              Text("Close", bundle: NativeControlResources.bundle)
            }
            .accessibilityIdentifier("openui.gallery.details.close")
          }
        }
      }
    }
    .onChange(of: images.map(\.key)) { keys in
      let current = Set(keys)
      phases = phases.filter { current.contains($0.key) }
      pictures = pictures.filter { current.contains($0.key) }
      if selected.map(current.contains) != true { preview = false; selected = nil }
    }
  }
  private func record(_ phase: NativeMediaStatus, image: Image?, for key: NativeGalleryResourceID) {
    guard images.contains(where: { $0.key == key }) else { return }
    if let image, pictures[key] == nil { pictures[key] = image }
    if phases[key] != .loaded && phases[key] != phase { phases[key] = phase }
  }
}

private struct NativeGalleryPreview: View {
  let images: [NativeGalleryImage]
  @Binding var selected: NativeGalleryResourceID?
  let pictures: [NativeGalleryResourceID: Image]
  let phases: [NativeGalleryResourceID: NativeMediaStatus]
  let record: (NativeMediaStatus, Image?, NativeGalleryResourceID) -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openUITheme) private var theme
  private var image: NativeGalleryImage? { images.first { $0.key == selected } }
  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing("m")) {
      HStack {
        Text("All photos", bundle: NativeControlResources.bundle).font(theme.typography.heading)
        Spacer()
        if let image { Text("\(image.index + 1) / \(images.count)").font(theme.typography.detail).foregroundStyle(theme.secondary) }
        Button { dismiss() } label: { Image(systemName: "xmark") }
          .buttonStyle(.plain).frame(minWidth: 44, minHeight: 44).disabled(false)
          .keyboardShortcut(.cancelAction).accessibilityLabel(Text("Close gallery", bundle: NativeControlResources.bundle))
          .accessibilityIdentifier("openui.gallery.close")
      }
      if let image {
        GeometryReader { _ in
          NativeRemoteImage(src: image.src, alt: image.alt, layout: .fit,
            cachedImage: pictures[image.key], onStatus: { record($0, $1, image.key) })
        }.accessibilityIdentifier("openui.gallery.preview.image")
        if !image.alt.isEmpty { Text(image.alt).font(theme.typography.detail) }
        if let details = image.details { Text(details).font(theme.typography.caption).foregroundStyle(theme.secondary) }
      }
      ScrollView(.horizontal) {
        HStack(spacing: theme.contentSpacing) {
          ForEach(images) { image in
            Button { selected = image.key } label: {
              NativeRemoteImage(src: image.src, alt: image.alt,
                layout: .thumbnail(CGSize(width: theme.compactThumbnailSize, height: theme.compactThumbnailSize * 3 / 4)),
                cachedImage: pictures[image.key], onStatus: { record($0, $1, image.key) })
                .clipShape(RoundedRectangle(cornerRadius: theme.mediaCornerRadius))
                .overlay(RoundedRectangle(cornerRadius: theme.mediaCornerRadius).strokeBorder(selected == image.key ? theme.accent : .clear, lineWidth: 2))
            }.buttonStyle(.plain).disabled(phases[image.key] == .unavailable)
              .accessibilityLabel(image.alt.isEmpty ? Text("View image", bundle: NativeControlResources.bundle) : Text(image.alt))
              .accessibilityIdentifier("openui.gallery.thumbnail.\(image.index)")
          }
        }
      }
    }
    .padding(20).frame(idealWidth: 720, idealHeight: 640)
    .accessibilityElement(children: .contain).accessibilityIdentifier("openui.gallery.preview")
  }
}
