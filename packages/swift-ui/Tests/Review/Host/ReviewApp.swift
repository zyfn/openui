import Foundation
import OpenUISwiftUI
import OpenUIWeb
import SwiftUI

@main
@MainActor
struct ComponentVisualHostApp: App {
  private let configuration = ReviewConfiguration()
  private let library = try! OpenUIWebComponents.install(
    into: OpenUIPopoverComponents.install(into: OpenUIMapComponents.library(basemapCoordinateSystem: .gcj02)))

  init() { _ = URLProtocol.registerClass(ReviewImageProtocol.self) }

  var body: some Scene {
    WindowGroup {
      if let mode = configuration.streamingCase {
        ReviewStreamingWorkspace(library: library, mode: mode)
      } else if configuration.audit {
        ReviewEngineAuditView(library: library)
      } else {
        ReviewWorkspace(library: library, configuration: configuration)
      }
    }
  }
}
