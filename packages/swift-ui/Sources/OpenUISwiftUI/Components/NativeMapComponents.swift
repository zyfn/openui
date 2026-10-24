import MapKit
import OpenUILang
import SwiftUI

/// An opt-in platform component. The pinned upstream collection remains 82 names.
public enum OpenUIMapComponents {
  public static func library(
    id: String? = nil, basemapCoordinateSystem: OpenUIMapCoordinateSystem = .wgs84
  ) throws -> OpenUIComponentLibrary {
    try install(
      into: OpenUIStandardComponents.library(id: id),
      basemapCoordinateSystem: basemapCoordinateSystem)
  }

  public static func install(
    into base: OpenUIComponentLibrary,
    basemapCoordinateSystem: OpenUIMapCoordinateSystem = .wgs84
  ) throws -> OpenUIComponentLibrary {
    let map = OpenUIComponent(
      name: "Map",
      description: """
        Native map for supplied places and route vertices. Never geocode, invent coordinates,
        or connect places when routes are absent. Points have stable id, title, lat and lng;
        optional subtitle, imageSrc, url and icon are factual place metadata. icon is an SF Symbol
        name, never a rating. Each routes entry
        is one actual polyline segment. crs states whether coordinates are wgs84 or gcj02.
        A bound value is the selected point id. size controls map prominence. Optional content
        is an object keyed by point id; each value is an ordinary component or array of components.
        Content appears as horizontally swipeable ordinary components INSIDE the map's bottom
        edge, without pagination chrome. The camera reserves space above this content. Swiping selects
        the corresponding marker; selecting a marker displays its page. Compose each page with
        Card, Stack, ImageText, Buttons etc. When content is omitted, valid supplied points use a
        compact default place card with title and available subtitle/image. No missing facts are
        invented. No coordinates means no point or place card. Routes alone may still render.
        """,
      params: [
        .init(
          name: "points", required: true,
          schema: .object([
            .init(key: "type", value: .string("array")),
            .init(key: "items", value: pointSchema),
          ])),
        .init(
          name: "routes", required: false,
          schema: .object([
            .init(key: "type", value: .string("array")),
            .init(
              key: "items",
              value: .object([
                .init(key: "type", value: .string("array")),
                .init(key: "items", value: coordinateSchema),
              ])),
          ])),
        OpenUIParameter.selection("value", required: false),
        OpenUIParameter.string(
          "size", required: false, values: ["compact", "regular", "expanded"]),
        OpenUIParameter.string("crs", required: false, values: ["wgs84", "gcj02"]),
        .init(name: "content", required: false, schema: .object([
          .init(key: "type", value: .string("object")),
          .init(key: "additionalProperties", value: .object([])),
          .init(key: "description", value: .string("Point id to component/page content. Use the same stable ids as points; each value may be a component or an array.")),
        ])),
      ]
    ) { context in
      NativeMapBlock(context: context, basemapCoordinateSystem: basemapCoordinateSystem)
    }
    // Stack.children accepts any component already. These typed slots require
    // explicit extension through lang-core's existing authoring API.
    return try base.extending(
      adding: [map],
      slots: [
        "Map": base.standardContentSlots
      ])
  }

  private static let coordinateSchema: JSONValue = .object([
    .init(key: "type", value: .string("object")),
    .init(
      key: "properties",
      value: .object([
        .init(key: "lat", value: degreeSchema(min: -90, max: 90)),
        .init(key: "lng", value: degreeSchema(min: -180, max: 180)),
      ])),
    .init(key: "required", value: .array([.string("lat"), .string("lng")])),
    .init(key: "additionalProperties", value: .boolean(false)),
  ])
  private static let pointSchema: JSONValue = .object([
    .init(key: "type", value: .string("object")),
    .init(
      key: "properties",
      value: .object([
        .init(key: "id", value: .object([.init(key: "type", value: .string("string"))])),
        .init(key: "title", value: .object([.init(key: "type", value: .string("string"))])),
        .init(key: "subtitle", value: .object([.init(key: "type", value: .string("string"))])),
        .init(key: "imageSrc", value: .object([.init(key: "type", value: .string("string"))])),
        .init(key: "url", value: .object([.init(key: "type", value: .string("string"))])),
        .init(key: "icon", value: .object([.init(key: "type", value: .string("string"))])),
        .init(key: "lat", value: degreeSchema(min: -90, max: 90)),
        .init(key: "lng", value: degreeSchema(min: -180, max: 180)),
      ])),
    .init(
      key: "required",
      value: .array(
        ["id", "title", "lat", "lng"].map(JSONValue.string))),
    .init(key: "additionalProperties", value: .boolean(false)),
  ])

  private static func degreeSchema(min: Int, max: Int) -> JSONValue {
    .object([
      .init(key: "type", value: .string("number")),
      .init(key: "minimum", value: .number(Double(min))),
      .init(key: "maximum", value: .number(Double(max))),
    ])
  }
}

/// MapKit basemap coordinates vary by region; the host selects what its map
/// displays. The OpenUI program declares the source CRS with Map.crs.
public enum OpenUIMapCoordinateSystem: String, Sendable {
  case wgs84
  case gcj02
}

struct NativeMapCoordinate: Equatable {
  let latitude: Double
  let longitude: Double

  var location: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  static func read(
    _ value: Value, source: OpenUIMapCoordinateSystem,
    target: OpenUIMapCoordinateSystem
  ) -> NativeMapCoordinate? {
    guard let lat = NativeValue.number(value, "lat"),
      let lng = NativeValue.number(value, "lng"),
      (-90...90).contains(lat), (-180...180).contains(lng)
    else { return nil }
    return NativeMapCoordinate(latitude: lat, longitude: lng).converted(from: source, to: target)
  }

  private func converted(
    from source: OpenUIMapCoordinateSystem, to target: OpenUIMapCoordinateSystem
  ) -> NativeMapCoordinate {
    guard source != target else { return self }
    return target == .wgs84 ? removingGCJ02() : applyingGCJ02()
  }

  private func removingGCJ02() -> NativeMapCoordinate {
    guard inMainlandBounds else { return self }
    var estimate = self
    for _ in 0..<10 {
      let projected = estimate.applyingGCJ02()
      let latError = projected.latitude - latitude
      let lngError = projected.longitude - longitude
      estimate = NativeMapCoordinate(
        latitude: estimate.latitude - latError, longitude: estimate.longitude - lngError)
      if max(abs(latError), abs(lngError)) < 1e-9 { break }
    }
    return estimate
  }

  private var inMainlandBounds: Bool {
    (72.004...137.8347).contains(longitude) && (0.8293...55.8271).contains(latitude)
  }

  private func applyingGCJ02() -> NativeMapCoordinate {
    guard inMainlandBounds else { return self }
    let x = longitude - 105
    let y = latitude - 35
    let pi = Double.pi
    var lat = -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
    lat += (20 * sin(6 * x * pi) + 20 * sin(2 * x * pi)) * 2 / 3
    lat += (20 * sin(y * pi) + 40 * sin(y / 3 * pi)) * 2 / 3
    lat += (160 * sin(y / 12 * pi) + 320 * sin(y * pi / 30)) * 2 / 3
    var lng = 300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
    lng += (20 * sin(6 * x * pi) + 20 * sin(2 * x * pi)) * 2 / 3
    lng += (20 * sin(x * pi) + 40 * sin(x / 3 * pi)) * 2 / 3
    lng += (150 * sin(x / 12 * pi) + 300 * sin(x * pi / 30)) * 2 / 3
    let radians = latitude / 180 * pi
    let eccentricity = 0.00669342162296594323
    let axis = 6378245.0
    let magic = 1 - eccentricity * pow(sin(radians), 2)
    lat = lat * 180 / ((axis * (1 - eccentricity) / (magic * sqrt(magic))) * pi)
    lng = lng * 180 / (axis / sqrt(magic) * cos(radians) * pi)
    return NativeMapCoordinate(latitude: latitude + lat, longitude: longitude + lng)
  }
}

struct NativeMapPoint: Equatable, Identifiable {
  let id: OpenUIString
  let title: String
  let coordinate: NativeMapCoordinate
  var subtitle: String? = nil
  var imageSrc: String? = nil
  var icon: String? = nil
}

struct NativeMapData: Equatable {
  let points: [NativeMapPoint]
  let routes: [[NativeMapCoordinate]]

  init(context: OpenUIComponentContext, target: OpenUIMapCoordinateSystem) {
    let source = OpenUIMapCoordinateSystem(rawValue: context.string("crs") ?? "") ?? .wgs84
    var seen = Set<OpenUIString>()
    points = NativeValue.array(context.value("points")).compactMap { item in
      guard case .string(let id) = NativeValue.prop(item, "id"), !id.isEmpty,
        !seen.contains(id),
        let title = NativeValue.string(item, "title"), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        let coordinate = NativeMapCoordinate.read(item, source: source, target: target)
      else { return nil }
      seen.insert(id)
      return NativeMapPoint(
        id: id, title: title, coordinate: coordinate,
        subtitle: NativeValue.string(item, "subtitle"), imageSrc: NativeValue.string(item, "imageSrc"),
        icon: NativeValue.string(item, "icon"))
    }
    var segments: [[NativeMapCoordinate]] = []
    for route in NativeValue.array(context.value("routes")) {
      var segment: [NativeMapCoordinate] = []
      for vertex in NativeValue.array(route) {
        if let point = NativeMapCoordinate.read(vertex, source: source, target: target) {
          segment.append(point)
        } else {
          if segment.count >= 2 { segments.append(segment) }
          segment = []
        }
      }
      if segment.count >= 2 { segments.append(segment) }
    }
    routes = segments
  }
}

private struct NativeMapBlock: View {
  let context: OpenUIComponentContext
  let basemapCoordinateSystem: OpenUIMapCoordinateSystem
  @State private var localSelection: OpenUIString?
  @State private var expanded = false
  private var data: NativeMapData { NativeMapData(context: context, target: basemapCoordinateSystem) }
  private var selection: Binding<OpenUIString?> {
    let stored = context.binding("value")
    return Binding(get: {
      let chosen: OpenUIString?
      if let stored, case .string(let id) = stored.wrappedValue { chosen = id }
      else { chosen = localSelection }
      return data.points.first(where: { $0.id == chosen })?.id ?? data.points.first?.id
    }, set: { next in
      guard context.canInteract else { return }
      if let stored { stored.wrappedValue = next.map(Value.string) ?? .undefined }
      else { localSelection = next }
    })
  }
  private var ratio: CGFloat {
    switch context.string("size") {
    case "compact": return 16 / 10
    case "expanded": return 3 / 4
    default: return 4 / 3
    }
  }
  var body: some View {
    Group {
      if data.points.isEmpty && data.routes.isEmpty {
        EmptyView()
      } else { presentation(height: nil, expands: true) }
    }
    #if os(iOS)
    .fullScreenCover(isPresented: $expanded) { fullMap }
    #else
    .sheet(isPresented: $expanded) { fullMap.frame(minWidth: 500, minHeight: 600) }
    #endif
    .onAppear(perform: reconcileSelection)
    .onChange(of: data.points.map(\.id)) { _ in reconcileSelection() }
    .onChange(of: context.canInteract) { _ in reconcileSelection() }
  }
  private func reconcileSelection() {
    let ids = data.points.map(\.id)
    if let stored = context.binding("value") {
      guard context.canInteract else { return }
      if case .string(let value) = stored.wrappedValue, ids.contains(value) { return }
      let next = ids.first.map(Value.string) ?? .undefined
      if stored.wrappedValue != next { stored.wrappedValue = next }
    } else if !ids.contains(where: { $0 == localSelection }) {
      localSelection = ids.first
    }
  }
  private func presentation(height: CGFloat?, expands: Bool) -> some View {
    NativeMapPresentation(context: context, data: data, selection: selection, ratio: ratio,
      imposedHeight: height, expand: expands ? { expanded = true } : nil)
  }
  private var fullMap: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Map", bundle: NativeControlResources.bundle).font(.headline)
        Spacer()
        Button { expanded = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
          .buttonStyle(.plain).accessibilityLabel(Text("Close", bundle: NativeControlResources.bundle))
      }.padding(.horizontal, 16)
      GeometryReader { geometry in presentation(height: max(160, geometry.size.height), expands: false) }
    }
    .background(context.theme.controlSurface)
    .accessibilityElement(children: .contain).accessibilityIdentifier("openui.map.expanded")
  }
}

/// Inline and expanded viewports own their measurements independently. A card
/// grows naturally in an unconstrained message; only a bounded viewport scrolls
/// long card content. Camera padding uses that viewport's actual visible inset.
private struct NativeMapPresentation: View {
  let context: OpenUIComponentContext
  let data: NativeMapData
  @Binding var selection: OpenUIString?
  let ratio: CGFloat
  let imposedHeight: CGFloat?
  let expand: (() -> Void)?
  @State private var width: CGFloat = 0
  @State private var contentHeight: CGFloat = 0
  @Namespace private var measurementScope
  private func page(_ id: OpenUIString) -> Value {
    guard case .object(let content) = context.value("content") else { return .null }
    return content[id] ?? .null
  }
  private func usesDefaultCard(_ id: OpenUIString) -> Bool {
    guard case .object(let pages) = context.value("content") else { return true }
    return !pages.isEmpty && pages[id] == nil
  }
  private var contentIDs: [OpenUIString] {
    data.points.map(\.id).filter {
      if usesDefaultCard($0) { return true }
      if case .array(let items) = page($0), items.isEmpty { return false }
      return page($0) != .null && page($0) != .undefined
    }
  }
  private var hasContent: Bool { selection.map(contentIDs.contains) == true }
  private var inset: CGFloat { hasContent ? contentHeight + 24 : 0 }
  private var height: CGFloat { imposedHeight ?? (max(160, width / ratio) + inset) }
  private var maximumCardHeight: CGFloat? { imposedHeight.map { max(44, $0 - 160 - 24) } }
  var body: some View {
    NativeMapCanvas(data: data, selection: $selection, canInteract: context.canInteract,
      accent: context.theme.accent, bottomInset: inset)
      .frame(height: height)
      .overlay(alignment: .bottom) { contentPages.padding(12) }
      .clipShape(RoundedRectangle(cornerRadius: context.theme.cornerRadius))
      .overlay(alignment: .topTrailing) {
        if let expand {
          Button(action: expand) {
            Image(systemName: "arrow.up.left.and.arrow.down.right").font(.subheadline.weight(.semibold))
              .frame(width: 44, height: 44).background(context.theme.controlSurface, in: Circle())
          }.buttonStyle(.plain).disabled(!context.canInteract).padding(12)
            .accessibilityLabel(Text("Expand map", bundle: NativeControlResources.bundle))
        }
      }
      .overlay(RoundedRectangle(cornerRadius: context.theme.cornerRadius).strokeBorder(context.theme.border))
      .frame(maxWidth: .infinity)
      .background(GeometryReader { geometry in
        Color.clear.preference(key: NativeMapSizeKey.self, value: [measurementScope: geometry.size.width])
      })
      .onPreferenceChange(NativeMapSizeKey.self) { values in
        guard let next = values[measurementScope], next.isFinite, next > 0, abs(next - width) > 0.5 else { return }
        width = next
      }
  }
  @ViewBuilder private var contentPages: some View {
    if let selected = selection, contentIDs.contains(selected) {
      NativePager(ids: contentIDs, selection: Binding(get: { selection ?? selected }, set: { selection = $0 }),
        enabled: context.canInteract, identifier: "openui.map", showsControls: false,
        maximumHeight: maximumCardHeight) { id in
          if usesDefaultCard(id), let point = data.points.first(where: { $0.id == id }) {
            NativeMapPlaceCard(point: point, theme: context.theme)
          } else {
            VStack(alignment: .leading, spacing: context.theme.spacing("s")) { context.render(page(id)) }
          }
      }
      .background(GeometryReader { geometry in
        Color.clear.preference(key: NativeMapContentHeightKey.self, value: [measurementScope: geometry.size.height])
      })
      .onPreferenceChange(NativeMapContentHeightKey.self) { values in
        guard let next = values[measurementScope], next.isFinite, next > 0, abs(next - contentHeight) > 0.5 else { return }
        contentHeight = next
      }
    }
  }
}

/// A generic place preview, used only when the program supplies no custom page.
/// Missing optional facts consume no space. Resource loading stays in the shared pipeline.
private struct NativeMapPlaceCard: View {
  let point: NativeMapPoint
  let theme: OpenUITheme
  @Environment(\.openUIResourceContext) private var resources
  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      if let source = point.imageSrc, resources.request(for: source) != nil {
        NativeRemoteImage(src: source, alt: point.title, layout: .thumbnail(CGSize(width: 60, height: 60)))
          .clipShape(RoundedRectangle(cornerRadius: theme.mediaCornerRadius))
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(point.title).font(theme.typography.detail.weight(.semibold)).lineLimit(2)
          .foregroundStyle(theme.foreground)
        if let subtitle = point.subtitle, !subtitle.isEmpty {
          Text(subtitle).font(theme.typography.caption).lineLimit(2).foregroundStyle(theme.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: theme.cornerRadius + 4))
    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius + 4).strokeBorder(theme.border.opacity(0.6)))
    .shadow(color: .black.opacity(0.08), radius: 12, y: 3)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("openui.map.place." + point.id.displayString)
  }
}
private struct NativeMapSizeKey: PreferenceKey {
  static let defaultValue: [Namespace.ID: CGFloat] = [:]
  static func reduce(value: inout [Namespace.ID: CGFloat], nextValue: () -> [Namespace.ID: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}
private struct NativeMapContentHeightKey: PreferenceKey {
  static let defaultValue: [Namespace.ID: CGFloat] = [:]
  static func reduce(value: inout [Namespace.ID: CGFloat], nextValue: () -> [Namespace.ID: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}
