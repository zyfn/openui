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
  case aspect(CGFloat), thumbnail(CGSize), fit, intrinsic
}

/// Shared native resource presentation. Network failures stay outside language
/// diagnostics, and a failed resource does not retain a successful image's box.
struct NativeRemoteImage: View {
  let src: String?
  var alt = ""
  var layout: NativeMediaLayout = .aspect(4 / 3)
  var compactStates = false
  var cachedImage: Image?
  var onStatus: ((NativeMediaStatus, Image?) -> Void)?
  @State private var attempt = 0
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
        }.task(id: requestID) { await load() }
      } else {
        unavailable.onAppear { onStatus?(.unavailable, nil) }
      }
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
  @ViewBuilder private var loading: some View {
    if compactStates {
      HStack(spacing: 8) {
        ProgressView().controlSize(.small)
        Text("Loading image", bundle: NativeControlResources.bundle).font(.caption)
      }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .foregroundStyle(theme.secondary).accessibilityIdentifier("openui.media.loading")
    } else {
      canvas { ZStack { theme.surface; ProgressView() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading image", bundle: NativeControlResources.bundle))
        .accessibilityValue(alt)
        .accessibilityIdentifier("openui.media.loading")
    }
  }
  @ViewBuilder private var unavailable: some View {
    if case .thumbnail(let size) = layout {
      Image(systemName: "photo")
        .font(.body).foregroundStyle(theme.secondary)
        .frame(width: size.width, height: min(44, size.height))
        .accessibilityLabel(Text("Image unavailable", bundle: NativeControlResources.bundle))
        .accessibilityValue(alt).accessibilityIdentifier("openui.media.unavailable")
    } else if compactStates {
      Label { Text("Image unavailable", bundle: NativeControlResources.bundle) }
        icon: { Image(systemName: "photo") }
        .font(.caption).foregroundStyle(theme.secondary).frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier("openui.media.unavailable")
    } else {
      NativeMediaUnavailable(alt: alt, src: src, allowsActions: !cardIsAction) { attempt += 1 }
    }
  }
  // Source proportions determine ordinary image height. Only unusually tall
  // previews are contained in a portrait-shaped region; fit preserves all pixels.
  // This is a native visual default, not a Lang field or a web CSS requirement.
  private var previewAspectRatio: CGFloat {
    NativeMediaPreview.aspectRatio(sourceSize: imageSize)
  }
  @ViewBuilder private func canvas<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    let surface = Color.clear.overlay { content().accessibilityHidden(true) }.clipped().contentShape(Rectangle())
    switch layout {
    case .aspect(let ratio): surface.aspectRatio(ratio, contentMode: .fit)
    case .thumbnail(let size): surface.frame(width: size.width, height: size.height)
    case .fit: surface.frame(maxWidth: .infinity, maxHeight: .infinity)
    case .intrinsic: surface.aspectRatio(previewAspectRatio, contentMode: .fit)
    }
  }
}

private struct NativeMediaUnavailable: View {
  let alt: String
  let src: String?
  let allowsActions: Bool
  let retry: () -> Void
  @Environment(\.openUITheme) private var theme
  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: "photo").accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text("Image unavailable", bundle: NativeControlResources.bundle).font(.subheadline)
        if !alt.isEmpty { Text(alt).font(.caption) }
        if allowsActions { NativeOriginalImageLink(src: src) }
      }
      Spacer(minLength: 0)
      if allowsActions && src?.isEmpty == false {
        Button(action: retry) { Text("Retry", bundle: NativeControlResources.bundle) }
          .font(.caption.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
          .buttonStyle(.plain).accessibilityIdentifier("openui.media.retry")
      }
    }
    .foregroundStyle(theme.secondary).padding(10).frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.controlCornerRadius))
    .accessibilityElement(children: .contain).accessibilityIdentifier("openui.media.unavailable")
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
  // The pinned upstream ImageGallery previews five items, with Show All.
  private let previewLimit = 5
  private var images: [NativeGalleryImage] {
    context.children("images").enumerated().map { index, child in
      NativeGalleryImage(id: child.id, index: index,
        src: NativeValue.string(child.value, "src"), alt: NativeValue.string(child.value, "alt") ?? "",
        details: NativeValue.string(child.value, "details"),
        requestID: .init(request: resources.request(for: NativeValue.string(child.value, "src")),
          loader: ObjectIdentifier(resources.loader), attempt: 0))
    }
  }
  private var visible: [NativeGalleryImage] { Array(images.filter { phases[$0.key] != .unavailable }.prefix(previewLimit)) }
  private var failed: [NativeGalleryImage] { images.filter { phases[$0.key] == .unavailable } }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !visible.isEmpty {
        LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())]
          : [GridItem(.adaptive(minimum: context.theme.minimumCompactCardWidth), spacing: 12)],
          alignment: .leading, spacing: 12) {
          ForEach(visible) { image in
            VStack(alignment: .leading, spacing: 6) {
              Button {
                selected = image.key; preview = true
              } label: {
                NativeRemoteImage(src: image.src, alt: image.alt, layout: .aspect(4 / 3), compactStates: true,
                  cachedImage: pictures[image.key], onStatus: { record($0, image: $1, for: image.key) })
                  .clipShape(RoundedRectangle(cornerRadius: context.theme.controlCornerRadius))
              }
              .buttonStyle(.plain).disabled(!context.canInteract || pictures[image.key] == nil)
              .accessibilityLabel(image.alt.isEmpty ? Text("View image", bundle: NativeControlResources.bundle) : Text(image.alt))
              .accessibilityValue(pictures[image.key] == nil ? Text("Loading image", bundle: NativeControlResources.bundle) : Text(""))
              .accessibilityIdentifier("openui.gallery.image.\(image.index)")
              if let details = image.details { Text(details).font(.caption).foregroundStyle(context.theme.secondary) }
            }
          }
        }
      }
      if images.count > previewLimit && !pictures.isEmpty {
        Button {
          if !images.contains(where: { $0.key == selected && pictures[$0.key] != nil }) {
            selected = images.first(where: { pictures[$0.key] != nil })?.key
          }
          preview = true
        } label: { Text("Show all photos", bundle: NativeControlResources.bundle) }
          .disabled(!context.canInteract).accessibilityIdentifier("openui.gallery.showAll")
      }
      if !failed.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("\(failed.count) images unavailable", bundle: NativeControlResources.bundle).font(.subheadline)
            Spacer(minLength: 0)
            Button {
              for image in failed { phases.removeValue(forKey: image.key) }
            } label: { Text("Retry", bundle: NativeControlResources.bundle) }
              .font(.caption.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
              .buttonStyle(.plain).disabled(!context.canInteract).accessibilityIdentifier("openui.gallery.retry")
          }
          DisclosureGroup {
            ForEach(failed) { image in
              VStack(alignment: .leading, spacing: 4) {
                if !image.alt.isEmpty { Text(image.alt).font(.subheadline) }
                if let details = image.details { Text(details).font(.caption) }
                NativeOriginalImageLink(src: image.src)
              }.padding(.vertical, 4)
            }
          } label: { Text("Image descriptions", bundle: NativeControlResources.bundle) }
            .font(.caption).accessibilityIdentifier("openui.gallery.details")
        }
        .foregroundStyle(context.theme.secondary).padding(12)
        .background(context.theme.surface, in: RoundedRectangle(cornerRadius: context.theme.controlCornerRadius))
        .accessibilityElement(children: .contain).accessibilityIdentifier("openui.gallery.unavailable")
      }
    }
    .accessibilityElement(children: .contain).accessibilityIdentifier("openui.gallery")
    .sheet(isPresented: $preview) {
      NativeGalleryPreview(images: images, selected: $selected, pictures: pictures, phases: phases, record: record)
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
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("All photos", bundle: NativeControlResources.bundle).font(.headline)
        Spacer()
        if let image { Text("\(image.index + 1) / \(images.count)").font(.subheadline).foregroundStyle(theme.secondary) }
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
        if !image.alt.isEmpty { Text(image.alt).font(.subheadline) }
        if let details = image.details { Text(details).font(.caption).foregroundStyle(theme.secondary) }
      }
      ScrollView(.horizontal) {
        HStack(spacing: 10) {
          ForEach(images) { image in
            Button { selected = image.key } label: {
              NativeRemoteImage(src: image.src, alt: image.alt, layout: .thumbnail(CGSize(width: 80, height: 60)),
                cachedImage: pictures[image.key], onStatus: { record($0, $1, image.key) })
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected == image.key ? theme.accent : .clear, lineWidth: 2))
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
