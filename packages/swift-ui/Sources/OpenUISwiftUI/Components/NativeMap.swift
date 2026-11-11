import MapKit
import OpenUILang
import SwiftUI

enum OpenUIGeographicComponents {
    static var map: OpenUIComponent {
        OpenUIComponent(name: "Map", description: "Use when spatial relationships help the user understand content, compare locations, or plan a route. Place data and coordinates must come from reliable sources.", params: [
            OpenUIParameter.slot("points", required: true, accepting: ["MapPoint"]),
            OpenUIParameter.string("crs", required: false, values: ["wgs84", "gcj02"])
        ]) { context in
            if #available(iOS 17, macOS 14, *) { MainActor.assumeIsolated { NativeMap(context: context) } }
            else { Text("Map requires iOS 17 or macOS 14", bundle: NativeControlResources.bundle)
                .nativeTextStyle(context.theme.textStyle(.supporting)) }
        }
    }
    static var mapPoint: OpenUIComponent {
        OpenUIComponent(name: "MapPoint", description: "A geographically locatable place. A name, latitude, and longitude are required.", params: [
            OpenUIParameter.string("title"), OpenUIParameter.number("lat", required: true), OpenUIParameter.number("lng", required: true),
            OpenUIParameter.string("imageSrc", required: false), OpenUIParameter.string("url", required: false),
            OpenUIParameter.string("description", required: false)
        ]) { _ in EmptyView() }
    }
}

/// Presentation identity is derived locally; the model supplies no ids or groups.
struct NativeMapPlace: Identifiable {
    let id: String
    let title: String
    let image: String?
    let url: String?
    let description: String?
    let coordinate: CLLocationCoordinate2D

    static func decode(_ values: Value?, crs: String) -> [Self] {
        guard ["wgs84", "gcj02"].contains(crs) else { return [] }
        var seen = Set<String>()
        return NativeValue.array(values).compactMap { value in
            guard case .element(let element) = value, element.typeName == "MapPoint",
                  let title = PropValue.string(element, "title"), !title.isEmpty,
                  ["title", "lat", "lng"].allSatisfy({ element.sourceReadiness[$0].complete }),
                  let lat = NativeMapValue.number(element.props.last { $0.0 == "lat" }?.1), let lng = NativeMapValue.number(element.props.last { $0.0 == "lng" }?.1),
                  lat.isFinite, lng.isFinite, (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }
            // Length-prefix the display name and use exact coordinate bits, not
            // an array index, so sorting or appended metadata doesn't change it.
            let id = "\(title.utf8.count):\(title):\(lat.bitPattern):\(lng.bitPattern)"
            guard seen.insert(id).inserted else { return nil }
            return Self(id: id, title: title, image: element.isSourceComplete ? PropValue.string(element, "imageSrc") : nil,
                        url: element.isSourceComplete ? PropValue.string(element, "url") : nil,
                        description: PropValue.string(element, "description"),
                        coordinate: NativeMapCoordinates.wgs84(latitude: lat, longitude: lng, source: crs))
        }
    }

}

@available(iOS 17, macOS 14, *)
private struct NativeMap: View {
    let context: OpenUIComponentContext
    @State private var localSelection: String?
    @State private var camera: MapCameraPosition = .automatic
    @State private var fullscreenCamera: MapCameraPosition = .automatic
    @State private var expanded = false
    @ScaledMetric(relativeTo: .subheadline) private var textBlockHeight: CGFloat = 54
    @Environment(\.openUIResourceContext) private var resources
    @Environment(\.openURL) private var openURL
    private var surfaceColor: Color {
        context.theme.foreground
    }
    private var places: [NativeMapPlace] {
        guard context.element.sourceReadiness["crs"].complete else { return [] }
        return NativeMapPlace.decode(context.value("points"), crs: context.string("crs") ?? "wgs84")
    }
    private var selectedID: String {
        places.first(where: { $0.id == localSelection })?.id ?? places.first?.id ?? ""
    }
    private func number(_ place: NativeMapPlace) -> Int {
        (places.firstIndex { $0.id == place.id } ?? 0) + 1
    }
    private func select(_ id: String) {
        guard context.canInteract, let place = places.first(where: { $0.id == id }) else { return }
        localSelection = id
        // Use a consistent neighborhood context instead of reusing a region
        // reported by the other (inline/fullscreen) map instance.
        withAnimation(.easeInOut(duration: 0.25)) {
            let position = MapCameraPosition.region(MKCoordinateRegion(center: place.coordinate,
                                                latitudinalMeters: 1600, longitudinalMeters: 1600))
            camera = position; fullscreenCamera = position
        }
    }
    private var selectedIndex: Int { places.firstIndex { $0.id == selectedID } ?? 0 }
    private func moveSelection(_ offset: Int) {
        let index = selectedIndex + offset
        guard places.indices.contains(index) else { return }
        select(places[index].id)
    }
    private func restoreInlineOverview() {
        // The preview returns to an overview without losing the selected card.
        // The point collection is never reduced by the name picker.
        if !places.contains(where: { $0.id == localSelection }) { localSelection = places.first?.id }
        camera = .automatic
    }
    private func fitPlaces() {
        if places.count == 1, let place = places.first {
            let position = MapCameraPosition.region(MKCoordinateRegion(center: place.coordinate,
                                                latitudinalMeters: 1600, longitudinalMeters: 1600))
            camera = position; fullscreenCamera = position
        } else { camera = .automatic; fullscreenCamera = .automatic }
    }
    private var cardBaseHeight: CGFloat { max(80, textBlockHeight + 24) }
    var body: some View {
        if !places.isEmpty || context.isStreaming {
            Color.clear.aspectRatio(1.1, contentMode: .fit)
                .frame(minHeight: 320, maxHeight: 360)
                .overlay {
                    if !places.isEmpty {
                        surface(fullscreen: false)
                    } else {
                        Color.secondary.opacity(0.06)
                            .overlay { NativePendingContent(loading: context.isStreaming, message: "Loading") }
                            .accessibilityIdentifier("openui.map.pending")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: context.theme.radius5xl))
                .overlay(RoundedRectangle(cornerRadius: context.theme.radius5xl).stroke(.primary.opacity(0.06)))
                .accessibilityIdentifier("openui.map")
            #if os(iOS)
            .fullScreenCover(isPresented: $expanded, onDismiss: restoreInlineOverview) { surface(fullscreen: true) }
            #else
            .sheet(isPresented: $expanded, onDismiss: restoreInlineOverview) { surface(fullscreen: true) }
            #endif
            .task(id: "\(context.canInteract):\(places.map(\.id))") {
                guard context.canInteract else { return }
                if !places.contains(where: { $0.id == localSelection }) {
                    localSelection = places.first?.id
                }
                fitPlaces()
            }

        }
    }
    private var pointMenu: some View {
        Menu {
            Button { fitPlaces() } label: {
                Label { Text("Show all places", bundle: NativeControlResources.bundle) } icon: { Image(systemName: "scope") }
            }
            ForEach(places) { place in
                Button { select(place.id) } label: {
                    if selectedID == place.id {
                        Label("\(number(place)). \(place.title)", systemImage: "checkmark")
                    } else { Text("\(number(place)). \(place.title)") }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.body.weight(.medium)).frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(Text("Choose a place", bundle: NativeControlResources.bundle))
        .disabled(!context.canInteract)
    }
    private func groupButton(_ title: LocalizedStringKey, icon: String, disabled: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.body.weight(.medium))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(Text(title, bundle: NativeControlResources.bundle)).disabled(disabled)
    }
    private func capsuleGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0, content: content)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(.primary.opacity(0.06)))
            .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
    }
    private func mapButton(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.body.weight(.medium))
                .frame(width: 44, height: 44)
                .background(surfaceColor, in: Circle())
                .overlay(Circle().stroke(.primary.opacity(0.06)))
                .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
        }
        .buttonStyle(.plain).accessibilityLabel(Text(title, bundle: NativeControlResources.bundle))
    }
    private func controls(fullscreen: Bool) -> some View {
        HStack(spacing: 8) {
            if fullscreen {
                mapButton("Close map", icon: "xmark") { expanded = false }
                Spacer(minLength: 0)
                capsuleGroup {
                    groupButton("Previous place", icon: "arrow.left", disabled: selectedIndex == 0 || !context.canInteract) { moveSelection(-1) }
                    groupButton("Next place", icon: "arrow.right", disabled: selectedIndex >= places.count - 1 || !context.canInteract) { moveSelection(1) }
                }
                capsuleGroup {
                    groupButton("Recenter on selection", icon: "location", disabled: !context.canInteract) { select(selectedID) }
                    pointMenu
                }
            } else {
                Spacer(minLength: 8)
                mapButton("Expand map", icon: "arrow.up.left.and.arrow.down.right") {
                    fullscreenCamera = camera; expanded = true
                }
            }
        }.padding(.horizontal, 14).padding(.top, 14)
    }
    private func marker(_ place: NativeMapPlace) -> some View {
        let selected = selectedID == place.id
        return Button { select(place.id) } label: {
            Text("\(number(place))").font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(selected ? surfaceColor : .primary)
                .frame(width: selected ? 38 : 32, height: selected ? 38 : 32)
                .background(selected ? Color.primary : surfaceColor, in: Circle())
                .overlay(Circle().stroke(surfaceColor.opacity(0.9), lineWidth: selected ? 2 : 1))
                .shadow(color: .black.opacity(selected ? 0.22 : 0.12), radius: 5, y: 2)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!context.canInteract)
        .accessibilityLabel(place.title)
        .accessibilityValue(Text(selected ? "Selected" : "Not selected", bundle: NativeControlResources.bundle))
    }
    private func surface(fullscreen: Bool) -> some View {
        Map(position: fullscreen ? $fullscreenCamera : $camera, interactionModes: fullscreen ? .all : [.zoom]) {
            ForEach(places) { place in
                Annotation(place.title, coordinate: place.coordinate) { marker(place) }
                    .annotationTitles(.visible)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .safeAreaInset(edge: .top, spacing: 0) { controls(fullscreen: fullscreen) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !places.isEmpty { pages.padding(.bottom, 12) }
        }
        .onChange(of: places.map(\.id)) { _, _ in fitPlaces() }
    }
    private var pages: some View {
        MapPlaceCarousel(places: places, selectedID: selectedID, minimumHeight: cardBaseHeight,
                         surfaceColor: surfaceColor, onSelect: select) { page($0, width: $1) }
    }
    private func page(_ place: NativeMapPlace, width: CGFloat) -> some View {
        let side = min(72, max(48, width * 0.20))
        let rowHeight = max(side, textBlockHeight)
        return HStack(spacing: 10) {
            NativeRemoteImage(src: place.image, alt: place.title, layout: .fill)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(place.title).nativeTextStyle(context.theme.textStyle(.fieldLabel)).lineLimit(2)
                if let description = place.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(description).nativeTextStyle(context.theme.textStyle(.caption)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: rowHeight, alignment: .leading)
            .clipped()
            if let address = place.url, let url = NativeMapValue.url(address, baseURL: resources.baseURL) {
                Button { openURL(url) } label: {
                    Image(systemName: "chevron.right").font(.body.weight(.semibold))
                        .foregroundStyle(.secondary).frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(!context.canInteract)
                .accessibilityLabel(Text("Details for \(place.title)", bundle: NativeControlResources.bundle))
                .accessibilityIdentifier("openui.map.details")
            } else {
                // Keep the text column stable while an optional source URL is
                // still arriving, without showing an unavailable action.
                Color.clear.frame(width: 44, height: 44).accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        // Reserve the same row for every card. Streaming or long descriptions
        // can change text, never the card's geometry or the photo column.
        .frame(maxWidth: .infinity).frame(height: rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("openui.map.place-card." + place.id)
    }

}
/// Each presented map owns its own viewport. Sharing the scroll-position
/// binding between inline and fullscreen views leaves a new view at page one.
@available(iOS 17, macOS 14, *)
private struct MapPlaceCarousel<Page: View>: View {
    let places: [NativeMapPlace]
    let selectedID: String
    let minimumHeight: CGFloat
    let surfaceColor: Color
    let onSelect: (String) -> Void
    @ViewBuilder let page: (NativeMapPlace, CGFloat) -> Page
    @State private var scrolledID: String?
    @State private var pageHeights: [String: CGFloat] = [:]
    @Environment(\.openUITheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(places) { place in
                            let width = places.count > 1 ? max(200, geometry.size.width - 56) : max(1, geometry.size.width - 28)
                            page(place, width).padding(12)
                                .frame(width: width, alignment: .leading)
                                .background(surfaceColor, in: RoundedRectangle(cornerRadius: theme.radius5xl))
                                .overlay(RoundedRectangle(cornerRadius: theme.radius5xl).stroke(.primary.opacity(0.06)))
                                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
                                .fixedSize(horizontal: false, vertical: true)
                                .background(GeometryReader { card in
                                    Color.clear.preference(key: PageHeight.self, value: [place.id: card.size.height])
                                })
                                .id(place.id)
                        }
                    }.scrollTargetLayout()
                }
                .contentMargins(.horizontal, 14, for: .scrollContent)
                .scrollIndicators(.hidden).scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrolledID, anchor: .leading)
                .onAppear {
                    scrolledID = selectedID
                    proxy.scrollTo(selectedID, anchor: .leading)
                }
                .onChange(of: selectedID) { _, id in
                    if scrolledID != id {
                        scrolledID = id
                        proxy.scrollTo(id, anchor: .leading)
                    }
                }
                .onChange(of: places.map(\.id)) { _, _ in
                    scrolledID = selectedID
                    proxy.scrollTo(selectedID, anchor: .leading)
                }
                .onChange(of: scrolledID) { _, id in
                    if let id, id != selectedID { onSelect(id) }
                }
            }
        }
        .frame(height: min(260, max(minimumHeight, places.compactMap { pageHeights[$0.id] }.max() ?? minimumHeight)))
        .onPreferenceChange(PageHeight.self) { pageHeights.merge($0, uniquingKeysWith: { _, new in new }) }
        .accessibilityIdentifier("openui.map.placeCards")
    }
}
private struct PageHeight: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

// MapKit consumes WGS-84 coordinates for place annotations.
enum NativeMapCoordinates {
    static func wgs84(latitude: Double, longitude: Double, source: String) -> CLLocationCoordinate2D {
        guard source == "gcj02", (72.004...137.8347).contains(longitude), (0.8293...55.8271).contains(latitude) else {
            return .init(latitude: latitude, longitude: longitude)
        }
        var estimate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        for _ in 0..<10 {
            let projected = gcj02(latitude: estimate.latitude, longitude: estimate.longitude)
            let deltaLat = projected.latitude - latitude, deltaLng = projected.longitude - longitude
            estimate.latitude -= deltaLat; estimate.longitude -= deltaLng
            if max(abs(deltaLat), abs(deltaLng)) < 1e-9 { break }
        }
        return estimate
    }
    private static func gcj02(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        let x = longitude - 105, y = latitude - 35, pi = Double.pi
        var dLat = -100 + 2*x + 3*y + 0.2*y*y + 0.1*x*y + 0.2*sqrt(abs(x))
        dLat += (20*sin(6*x*pi) + 20*sin(2*x*pi))*2/3 + (20*sin(y*pi) + 40*sin(y*pi/3))*2/3 + (160*sin(y*pi/12) + 320*sin(y*pi/30))*2/3
        var dLng = 300 + x + 2*y + 0.1*x*x + 0.1*x*y + 0.1*sqrt(abs(x))
        dLng += (20*sin(6*x*pi) + 20*sin(2*x*pi))*2/3 + (20*sin(x*pi) + 40*sin(x*pi/3))*2/3 + (150*sin(x*pi/12) + 300*sin(x*pi/30))*2/3
        let rad = latitude*pi/180, axis = 6378245.0, e = 0.00669342162296594323
        let magic = 1-e*sin(rad)*sin(rad)
        dLat = dLat*180/(axis*(1-e)/(magic*sqrt(magic))*pi)
        dLng = dLng*180/(axis/sqrt(magic)*cos(rad)*pi)
        return .init(latitude: latitude+dLat, longitude: longitude+dLng)
    }
}

/// Resource links are host navigation, not map selection actions.
enum NativeMapValue {
    static func number(_ value: Value?) -> Double? {
        guard case .number(let number) = value, number.isFinite else { return nil }
        return number
    }
    static func url(_ source: String, baseURL: URL?) -> URL? {
        guard let url = URL(string: source, relativeTo: baseURL)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false, url.user == nil, url.password == nil else { return nil }
        return url
    }
}
