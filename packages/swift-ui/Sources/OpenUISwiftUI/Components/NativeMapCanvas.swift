import MapKit
import OpenUILang
import SwiftUI

#if os(iOS)
  import UIKit
  private typealias NativeMapColor = UIColor
#elseif os(macOS)
  import AppKit
  private typealias NativeMapColor = NSColor
#endif

/// Thin MapKit bridge. UI state remains in OpenUIState; MapKit owns only camera
/// position, annotation hit targets and the supplied polyline overlays.
#if os(iOS)
  struct NativeMapCanvas: UIViewRepresentable {
    let data: NativeMapData
    @Binding var selection: OpenUIString?
    let canInteract: Bool
    let accent: Color
    var bottomInset: CGFloat = 0

    func makeCoordinator() -> NativeMapCoordinator {
      NativeMapCoordinator(onSelection: { selection = $0 })
    }
    func makeUIView(context: Context) -> MKMapView { nativeMap(context.coordinator) }
    func updateUIView(_ view: MKMapView, context: Context) {
      context.coordinator.onSelection = { selection = $0 }
      context.coordinator.update(
        view, data: data, selected: selection, canInteract: canInteract, accent: accent, bottomInset: bottomInset)
    }
    static func dismantleUIView(_ view: MKMapView, coordinator: NativeMapCoordinator) {
      view.delegate = nil
    }
  }
#elseif os(macOS)
  struct NativeMapCanvas: NSViewRepresentable {
    let data: NativeMapData
    @Binding var selection: OpenUIString?
    let canInteract: Bool
    let accent: Color
    var bottomInset: CGFloat = 0

    func makeCoordinator() -> NativeMapCoordinator {
      NativeMapCoordinator(onSelection: { selection = $0 })
    }
    func makeNSView(context: Context) -> MKMapView { nativeMap(context.coordinator) }
    func updateNSView(_ view: MKMapView, context: Context) {
      context.coordinator.onSelection = { selection = $0 }
      context.coordinator.update(
        view, data: data, selected: selection, canInteract: canInteract, accent: accent, bottomInset: bottomInset)
    }
    static func dismantleNSView(_ view: MKMapView, coordinator: NativeMapCoordinator) {
      view.delegate = nil
    }
  }
#endif

@MainActor private func nativeMap(_ coordinator: NativeMapCoordinator) -> MKMapView {
  let view = NativeSizingMapView()
  view.onSizeChange = { [weak coordinator] view in coordinator?.viewportChanged(view) }
  view.delegate = coordinator
  view.mapType = .mutedStandard
  view.pointOfInterestFilter = .excludingAll
  view.showsUserLocation = false
  view.isRotateEnabled = false
  view.isPitchEnabled = false
  #if os(iOS)
    view.accessibilityIdentifier = "openui.map.canvas"
  #else
    view.setAccessibilityIdentifier("openui.map.canvas")
  #endif
  return view
}

private final class NativeSizingMapView: MKMapView {
  var onSizeChange: (@MainActor (MKMapView) -> Void)?
  private var previousSize = CGSize.zero
  #if os(iOS)
  override func layoutSubviews() { super.layoutSubviews(); reportSize() }
  #else
  override func layout() { super.layout(); reportSize() }
  #endif
  private func reportSize() {
    guard bounds.width > 0, bounds.height > 0, bounds.size != previousSize else { return }
    previousSize = bounds.size
    onSizeChange?(self)
  }
}

@MainActor
final class NativeMapCoordinator: NSObject, MKMapViewDelegate {
  var onSelection: (OpenUIString) -> Void
  private var lastData: NativeMapData?
  private var lastSelection: OpenUIString?
  private var applying = false
  private var lineColor = NativeMapColor.systemBlue
  private var interactive = false
  private var bottomInset: CGFloat = 0
  private var userAdjustedCamera = false
  private var lastAccent: Color?

  init(onSelection: @escaping (OpenUIString) -> Void) {
    self.onSelection = onSelection
  }

  func viewportChanged(_ view: MKMapView) {
    if !userAdjustedCamera { fit(view) }
  }

  func update(
    _ view: MKMapView, data: NativeMapData, selected: OpenUIString?,
    canInteract: Bool, accent: Color, bottomInset: CGFloat = 0
  ) {
    interactive = canInteract
    let accentChanged = lastAccent != accent
    lastAccent = accent
    lineColor = NativeMapColor(accent)
    let insetChanged = abs(self.bottomInset - bottomInset) > 0.5
    self.bottomInset = max(0, bottomInset)
    #if os(iOS)
      view.isUserInteractionEnabled = canInteract
    #else
      view.isScrollEnabled = canInteract
      view.isZoomEnabled = canInteract
    #endif
    if lastData != data {
      applying = true
      defer { applying = false }
      let current = view.annotations.compactMap { $0 as? NativeMapAnnotation }
      let nextByID = Dictionary(uniqueKeysWithValues: data.points.map { ($0.id, $0) })
      for old in current where nextByID[old.id] == nil { view.removeAnnotation(old) }
      let currentIDs = Set(current.map(\.id))
      for old in current {
        guard let point = nextByID[old.id] else { continue }
        old.title = point.title
        old.icon = point.icon
        old.coordinate = point.coordinate.location
        if let marker = view.view(for: old) as? NativeMapMarkerView {
          marker.configure(icon: point.icon, accent: NativeMapColor(accent), scale: markerScale(view))
        }
      }
      view.addAnnotations(
        data.points.filter { !currentIDs.contains($0.id) }
          .map(NativeMapAnnotation.init))
      let routesChanged = lastData?.routes != data.routes
      if routesChanged {
        view.removeOverlays(view.overlays)
        for route in data.routes {
          let points = route.map(\.location)
          view.addOverlay(MKPolyline(coordinates: points, count: points.count))
        }
      }
      let oldCoordinates = lastData?.points.map { $0.coordinate }
      lastData = data
      if oldCoordinates != data.points.map(\.coordinate) || routesChanged
        || view.region.span.latitudeDelta <= 0
      {
        if !userAdjustedCamera { fit(view) }
      }
    }
    if insetChanged && !userAdjustedCamera { fit(view) }
    if accentChanged {
      for annotation in view.annotations.compactMap({ $0 as? NativeMapAnnotation }) {
        (view.view(for: annotation) as? NativeMapMarkerView)?.configure(
          icon: annotation.icon, accent: lineColor, scale: markerScale(view))
      }
      for overlay in view.overlays {
        if let renderer = view.renderer(for: overlay) as? MKPolylineRenderer {
          renderer.strokeColor = lineColor; renderer.setNeedsDisplay()
        }
      }
    }
    if selected != lastSelection {
      applying = true
      defer { applying = false }
      if let selected,
        let annotation = view.annotations.compactMap({ $0 as? NativeMapAnnotation })
          .first(where: { $0.id == selected })
      {
        view.selectAnnotation(annotation, animated: false)
        reveal(annotation, in: view)
      } else {
        for annotation in view.selectedAnnotations {
          view.deselectAnnotation(annotation, animated: false)
        }
      }
      lastSelection = selected
    }
  }

  private func fit(_ view: MKMapView) {
    var bounds = MKMapRect.null
    for annotation in view.annotations.compactMap({ $0 as? NativeMapAnnotation }) {
      let point = MKMapPoint(annotation.coordinate)
      let lat = max(-85, min(85, annotation.coordinate.latitude))
      let radius = MKMapPointsPerMeterAtLatitude(lat) * 500
      bounds = bounds.union(
        MKMapRect(
          x: point.x - radius, y: point.y - radius,
          width: radius * 2, height: radius * 2))
    }
    for overlay in view.overlays { bounds = bounds.union(overlay.boundingMapRect) }
    if !bounds.isNull {
      #if os(iOS)
        view.setVisibleMapRect(
          bounds,
          edgePadding: UIEdgeInsets(top: 56, left: 28, bottom: 28 + bottomInset, right: 28), animated: false)
      #else
        view.setVisibleMapRect(
          bounds,
          edgePadding: NSEdgeInsets(top: 56, left: 28, bottom: 28 + bottomInset, right: 28), animated: false)
      #endif
    }
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
    guard let point = annotation as? NativeMapAnnotation else { return nil }
    let id = "sdk-map-marker"
    let view =
      (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? NativeMapMarkerView)
      ?? NativeMapMarkerView(annotation: annotation, reuseIdentifier: id)
    view.annotation = annotation
    view.canShowCallout = false
    view.configure(icon: point.icon, accent: lineColor, scale: markerScale(mapView))
    view.displayPriority = .required
    #if os(iOS)
      view.isAccessibilityElement = true
      view.accessibilityLabel = point.title
      view.accessibilityIdentifier = "openui.map.marker." + point.id.displayString
    #else
      view.setAccessibilityLabel(point.title)
      view.setAccessibilityIdentifier("openui.map.marker." + point.id.displayString)
    #endif
    return view
  }

  private func markerScale(_ view: MKMapView) -> CGFloat {
    #if os(iOS)
    view.contentScaleFactor
    #else
    view.window?.backingScaleFactor ?? 1
    #endif
  }

  private func reveal(_ annotation: NativeMapAnnotation, in view: MKMapView) {
    guard view.bounds.height > bottomInset + 80 else { return }
    let point = view.convert(annotation.coordinate, toPointTo: view)
    let usable = CGRect(x: 28, y: 56, width: max(1, view.bounds.width - 56),
                        height: max(1, view.bounds.height - bottomInset - 84))
    guard !usable.contains(point) else { return }
    let current = view.visibleMapRect
    let location = MKMapPoint(annotation.coordinate)
    let offset = current.height * Double(bottomInset) / Double(view.bounds.height) / 2
    applying = true
    view.setVisibleMapRect(MKMapRect(x: location.x - current.width / 2,
      y: location.y - current.height / 2 + offset, width: current.width, height: current.height), animated: false)
    applying = false
  }

  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    guard !applying else { return }
    #if os(iOS)
    func hasGesture(_ view: UIView) -> Bool {
      (view.gestureRecognizers ?? []).contains { $0.state == .began || $0.state == .changed }
        || view.subviews.contains(where: hasGesture)
    }
    if hasGesture(mapView) { userAdjustedCamera = true }
    #else
    if let type = NSApp.currentEvent?.type, [.scrollWheel, .leftMouseDragged, .magnify].contains(type) {
      userAdjustedCamera = true
    }
    #endif
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
    if let line = overlay as? MKPolyline {
      let renderer = MKPolylineRenderer(polyline: line)
      renderer.strokeColor = lineColor
      renderer.lineWidth = 4
      return renderer
    }
    return MKOverlayRenderer(overlay: overlay)
  }

  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard !applying, interactive, let point = view.annotation as? NativeMapAnnotation else {
      return
    }
    lastSelection = point.id
    onSelection(point.id)
  }
}

private final class NativeMapAnnotation: NSObject, MKAnnotation {
  let id: OpenUIString
  @objc dynamic var title: String?
  @objc dynamic var coordinate: CLLocationCoordinate2D
  var icon: String?

  init(_ point: NativeMapPoint) {
    id = point.id
    title = point.title
    coordinate = point.coordinate.location
    icon = point.icon
  }
}

/// Compact icon badges own a stable hit target. MapKit's automatic oversized
/// marker expansion is not used, and no score or inferred category is displayed.
private final class NativeMapMarkerView: MKAnnotationView {
  private var symbol = "mappin"
  private var accent = NativeMapColor.systemBlue
  private var scale: CGFloat = 1

  func configure(icon: String?, accent: NativeMapColor, scale: CGFloat) {
    symbol = icon ?? "mappin"; self.accent = accent; self.scale = scale
    redraw()
  }
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    redraw()
  }
  #if os(iOS)
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { redraw() }
  }
  #else
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    redraw()
  }
  #endif
  private func redraw() {
    let selected = isSelected
    let size = CGSize(width: 44, height: 44)
    let circle = CGRect(x: selected ? 3 : 6, y: selected ? 3 : 6,
                        width: selected ? 38 : 32, height: selected ? 38 : 32)
    #if os(iOS)
    let surface = NativeMapColor.systemBackground
    #else
    let surface = NativeMapColor.windowBackgroundColor
    #endif
    let fill = selected ? accent : surface
    let glyphColor = selected ? surface : accent
    let glyphSymbol = symbol
    func glyphRect(_ size: CGSize) -> CGRect {
      let factor = min(18 / max(1, size.width), 18 / max(1, size.height))
      let extent = CGSize(width: size.width * factor, height: size.height * factor)
      return CGRect(x: (44 - extent.width) / 2, y: (44 - extent.height) / 2,
                    width: extent.width, height: extent.height)
    }
    func background(_ context: CGContext) {
      context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4,
                        color: NativeMapColor.black.withAlphaComponent(0.16).cgColor)
      context.setFillColor(fill.cgColor); context.fillEllipse(in: circle)
      context.setShadow(offset: .zero, blur: 0, color: nil)
      context.setStrokeColor(NativeMapColor.white.withAlphaComponent(0.95).cgColor)
      context.setLineWidth(2); context.strokeEllipse(in: circle.insetBy(dx: 1, dy: 1))
    }
    #if os(iOS)
    let format = UIGraphicsImageRendererFormat(); format.scale = max(1, scale)
    image = UIGraphicsImageRenderer(size: size, format: format).image { drawing in
      background(drawing.cgContext)
      let glyph = UIImage(systemName: glyphSymbol) ?? UIImage(systemName: "mappin")
      if let glyph { glyph.withTintColor(glyphColor, renderingMode: .alwaysOriginal).draw(in: glyphRect(glyph.size)) }
    }
    layer.zPosition = selected ? 10 : 0
    #else
    image = NSImage(size: size, flipped: false) { _ in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      background(context)
      let glyph = NSImage(systemSymbolName: glyphSymbol, accessibilityDescription: nil)
        ?? NSImage(systemSymbolName: "mappin", accessibilityDescription: nil)
      if let glyph { glyph.withSymbolConfiguration(.init(paletteColors: [glyphColor]))?.draw(in: glyphRect(glyph.size)) }
      return true
    }
    layer?.zPosition = selected ? 10 : 0
    #endif
  }
}
