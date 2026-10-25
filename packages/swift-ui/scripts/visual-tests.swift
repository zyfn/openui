#!/usr/bin/env swift
import CryptoKit
import Darwin
import Foundation
import ImageIO

// Native visual review entry point. Test cases and assertions are Swift;
// this driver creates an isolated Xcode host and runs them on a selected device.
let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  .deletingLastPathComponent().standardizedFileURL
let repository = package.deletingLastPathComponent().deletingLastPathComponent()
let args = CommandLine.arguments
func option(_ flag: String) -> String? {
  guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
  return args[index + 1]
}
let output =
  option("--output").map { URL(fileURLWithPath: $0).standardizedFileURL }
  ?? repository.appendingPathComponent("work/component-visual-review")
let prepareOnly = args.contains("--prepare-only")
let buildStamp = String(Int(Date().timeIntervalSince1970))
guard prepareOnly || option("--simulator") != nil else {
  print(
    "Usage: swift packages/swift-ui/scripts/visual-tests.swift --simulator <UDID> [--output <directory>] [--suite quick|full] [--only-testing <Class/method>] [--review-program <file.openui>] [--review-examples <file.json>]\nUse --prepare-only to generate a project for Xcode or XcodeBuildMCP."
  )
  exit(2)
}
let files = FileManager.default
try files.createDirectory(at: output, withIntermediateDirectories: true)
let review = package.appendingPathComponent("Tests/Review")
let imageDirectory = review.appendingPathComponent("Fixtures/Images")
for file in try files.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil)
where ["png", "jpg", "jpeg"].contains(file.pathExtension.lowercased()) {
  let bytes = try Data(contentsOf: file)
  // ImageIO can tolerate a truncated download and still return partial pixels.
  // Curated fixtures use canonical endings; this check is not a runtime loader.
  let ending =
    file.pathExtension.lowercased() == "png"
    ? Data([0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82])
    : Data([0xFF, 0xD9])
  guard bytes.suffix(ending.count) == ending,
    let source = CGImageSourceCreateWithURL(file as CFURL, nil),
    CGImageSourceGetStatus(source) == .statusComplete,
    CGImageSourceCreateImageAtIndex(
      source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) != nil,
    CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
  else {
    print("Invalid or incomplete image fixture: \(file.lastPathComponent)")
    exit(2)
  }
}

func quote(_ value: String) -> String {
  let data = try! JSONSerialization.data(
    withJSONObject: [value], options: [.fragmentsAllowed, .withoutEscapingSlashes])
  return String(String(data: data, encoding: .utf8)!.dropFirst().dropLast())
}
func array(_ values: [String]) -> String {
  "(" + values.joined(separator: ", ") + (values.isEmpty ? "" : ",") + ")"
}
func identifier(_ key: String) -> String {
  String(SHA256.hash(data: Data(key.utf8)).map { String(format: "%02X", $0) }.joined().prefix(24))
}
var objects: [String] = []
@discardableResult func object(_ key: String, _ body: String) -> String {
  let id = identifier(key)
  objects.append("\(id) = { \(body) };")
  return id
}
func settings(_ values: [String: String]) -> String {
  values.keys.sorted().map { "\($0) = \(quote(values[$0]!));" }.joined()
}
func swiftFiles(in directory: URL) -> [URL] {
  let contents = files.enumerator(at: directory, includingPropertiesForKeys: nil)!
  return contents.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
}
let hostFiles = ["Catalog", "Host", "Fixtures"].flatMap { swiftFiles(in: review.appendingPathComponent($0)) }
  + [review.appendingPathComponent("Acceptance/EngineAudit.swift")]
let testFiles = swiftFiles(in: review.appendingPathComponent("Acceptance/UITests"))
var sourceReferences: [String] = []
func sourceBuilds(_ urls: [URL], target: String) -> [String] {
  urls.map { url in
    let ref = object(
      "file:" + url.path,
      "isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \(quote(url.path)); sourceTree = \"<absolute>\";"
    )
    sourceReferences.append(ref)
    return object("build:" + target + url.path, "isa = PBXBuildFile; fileRef = \(ref);")
  }
}
let hostSources = sourceBuilds(hostFiles, target: "host")
let testSources = sourceBuilds(testFiles, target: "test")
let hostProduct = object(
  "host-product",
  "isa = PBXFileReference; explicitFileType = wrapper.application; path = ComponentVisualHost.app; sourceTree = BUILT_PRODUCTS_DIR;"
)
let testProduct = object(
  "test-product",
  "isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = ComponentVisualUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;"
)
let baselines = object(
  "baseline-folder",
  "isa = PBXFileReference; lastKnownFileType = folder; path = \(quote(review.appendingPathComponent("Fixtures/Baselines").path)); sourceTree = \"<absolute>\";"
)
let baselineBuild = object("baseline-build", "isa = PBXBuildFile; fileRef = \(baselines);")
let images = object(
  "image-fixtures",
  "isa = PBXFileReference; lastKnownFileType = folder; path = \(quote(imageDirectory.path)); sourceTree = \"<absolute>\";"
)
let imageBuild = object("image-build", "isa = PBXBuildFile; fileRef = \(images);")
let testImageBuild = object("test-image-build", "isa = PBXBuildFile; fileRef = \(images);")
// Replay a saved program without committing conversation data to the SDK.
var reviewResources: [String] = []
var reviewReferences: [String] = []
if let path = option("--review-program") {
  let program = output.appendingPathComponent("ReviewProgram.openui")
  try Data(contentsOf: URL(fileURLWithPath: path)).write(to: program, options: .atomic)
  let reference = object(
    "review-program", "isa = PBXFileReference; lastKnownFileType = text; path = \(quote(program.path)); sourceTree = \"<absolute>\";")
  reviewReferences.append(reference)
  reviewResources.append(object("review-program-build", "isa = PBXBuildFile; fileRef = \(reference);"))
}
// Boundary programs are test resources, outside the finite design catalog.
var additionalPrograms: [[String: String]] = []
let boundaryPrograms = review.appendingPathComponent("Fixtures/Programs")
if files.fileExists(atPath: boundaryPrograms.path) {
  for source in try files.contentsOfDirectory(at: boundaryPrograms, includingPropertiesForKeys: nil)
    .filter({ $0.pathExtension == "openui" }).sorted(by: { $0.path < $1.path }) {
    let id = source.deletingPathExtension().lastPathComponent
    additionalPrograms.append(["id": id, "title": id.replacingOccurrences(of: "-", with: " "),
      "source": try String(contentsOf: source, encoding: .utf8)])
  }
}
if let path = option("--review-examples") {
  let supplied = try JSONDecoder().decode([[String: String]].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
  additionalPrograms += supplied
}
if !additionalPrograms.isEmpty {
  let examples = output.appendingPathComponent("ReviewExamples.json")
  try JSONSerialization.data(withJSONObject: additionalPrograms, options: [.sortedKeys]).write(to: examples)
  let reference = object("review-examples", "isa = PBXFileReference; lastKnownFileType = text.json; path = \(quote(examples.path)); sourceTree = \"<absolute>\";")
  reviewReferences.append(reference)
  reviewResources.append(object("review-examples-build", "isa = PBXBuildFile; fileRef = \(reference);"))
}
if let path = option("--stream-program") {
  let program = output.appendingPathComponent("StreamProgram.openui")
  try Data(contentsOf: URL(fileURLWithPath: path)).write(to: program, options: .atomic)
  let reference = object("stream-program", "isa = PBXFileReference; lastKnownFileType = text; path = \(quote(program.path)); sourceTree = \"<absolute>\";")
  reviewReferences.append(reference)
  reviewResources.append(object("stream-program-build", "isa = PBXBuildFile; fileRef = \(reference);"))
}
let sourceGroup = object(
  "sources",
  "isa = PBXGroup; name = Sources; children = \(array(sourceReferences + [baselines, images] + reviewReferences)); sourceTree = \"<group>\";"
)
let productGroup = object(
  "products",
  "isa = PBXGroup; name = Products; children = \(array([hostProduct, testProduct])); sourceTree = \"<group>\";"
)
let mainGroup = object(
  "main",
  "isa = PBXGroup; children = \(array([sourceGroup, productGroup])); sourceTree = \"<group>\";")
var dependencies: [String] = []
var products: [String] = []
var frameworks: [String] = []
var packageReferences: [String: String] = [:]
for (path, product) in [
  (package, "OpenUISwiftUI"),
  (package, "OpenUIWeb"),
  (package.deletingLastPathComponent().appendingPathComponent("swift-lang"), "OpenUILang"),
] {
  if packageReferences[path.path] == nil {
    let reference = object("package:" + path.path,
      "isa = XCLocalSwiftPackageReference; relativePath = \(quote(path.path));")
    packageReferences[path.path] = reference
    dependencies.append(reference)
  }
  let reference = object(
    "product:" + product, "isa = XCSwiftPackageProductDependency; productName = \(quote(product));")
  products.append(reference)
  frameworks.append(
    object("framework:" + product, "isa = PBXBuildFile; productRef = \(reference);"))
}
let hostPhase = object(
  "host-sources",
  "isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = \(array(hostSources)); runOnlyForDeploymentPostprocessing = 0;"
)
let testPhase = object(
  "test-sources",
  "isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = \(array(testSources)); runOnlyForDeploymentPostprocessing = 0;"
)
let frameworkPhase = object(
  "frameworks",
  "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = \(array(frameworks)); runOnlyForDeploymentPostprocessing = 0;"
)
let resourcePhase = object(
  "test-resources",
  "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = \(array([baselineBuild, testImageBuild] + reviewResources)); runOnlyForDeploymentPostprocessing = 0;"
)
let hostResources = object(
  "host-resources",
  "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = \(array([imageBuild] + reviewResources)); runOnlyForDeploymentPostprocessing = 0;"
)
var projectConfigs: [String] = []
var hostConfigs: [String] = []
var testConfigs: [String] = []
for configuration in ["Debug", "Release"] {
  let common = [
    "ONLY_ACTIVE_ARCH": configuration == "Debug" ? "YES" : "NO", "SDKROOT": "iphoneos",
    "IPHONEOS_DEPLOYMENT_TARGET": "15.0", "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": configuration == "Debug" ? "DEBUG" : "",
    "SWIFT_OPTIMIZATION_LEVEL": configuration == "Debug" ? "-Onone" : "-O",
    "CURRENT_PROJECT_VERSION": buildStamp,
  ]
  projectConfigs.append(
    object(
      "project-" + configuration,
      "isa = XCBuildConfiguration; name = \(configuration); buildSettings = {\(settings(common))};")
  )
  var host = [
    "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "dev.swiftui.component-review",
    "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_CFBundleDisplayName": "SDK Visual Review",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES", "TARGETED_DEVICE_FAMILY": "1,2",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
  ]
  hostConfigs.append(
    object(
      "host-" + configuration,
      "isa = XCBuildConfiguration; name = \(configuration); buildSettings = {\(settings(host))};"))
  host["PRODUCT_BUNDLE_IDENTIFIER"] = "dev.swiftui.component-review.uitests"
  host["TEST_TARGET_NAME"] = "ComponentVisualHost"
  testConfigs.append(
    object(
      "test-" + configuration,
      "isa = XCBuildConfiguration; name = \(configuration); buildSettings = {\(settings(host))};"))
}
func configList(_ key: String, _ configs: [String]) -> String {
  object(
    key,
    "isa = XCConfigurationList; buildConfigurations = \(array(configs)); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;"
  )
}
let projectConfig = configList("project-config", projectConfigs)
let hostConfig = configList("host-config", hostConfigs)
let testConfig = configList("test-config", testConfigs)
let hostTarget = object(
  "host-target",
  "isa = PBXNativeTarget; name = ComponentVisualHost; productName = ComponentVisualHost; productReference = \(hostProduct); productType = \"com.apple.product-type.application\"; buildConfigurationList = \(hostConfig); buildPhases = \(array([hostPhase, frameworkPhase, hostResources])); buildRules = (); dependencies = (); packageProductDependencies = \(array(products));"
)
let dependency = object("test-host", "isa = PBXTargetDependency; target = \(hostTarget);")
let testTarget = object(
  "test-target",
  "isa = PBXNativeTarget; name = ComponentVisualUITests; productName = ComponentVisualUITests; productReference = \(testProduct); productType = \"com.apple.product-type.bundle.ui-testing\"; buildConfigurationList = \(testConfig); buildPhases = \(array([testPhase, resourcePhase])); buildRules = (); dependencies = \(array([dependency]));"
)
let projectID = object(
  "project",
  "isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2600; TargetAttributes = { \(testTarget) = { TestTargetID = \(hostTarget); }; }; }; buildConfigurationList = \(projectConfig); compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; knownRegions = (en, Base); mainGroup = \(mainGroup); productRefGroup = \(productGroup); projectDirPath = \"\"; projectRoot = \"\"; packageReferences = \(array(dependencies)); targets = \(array([hostTarget, testTarget]));"
)
let project = output.appendingPathComponent("ComponentVisualReview.xcodeproj")
let schemes = project.appendingPathComponent("xcshareddata/xcschemes")
try files.createDirectory(at: schemes, withIntermediateDirectories: true)
try
  ("// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n"
  + objects.joined(separator: "\n") + "\n}; rootObject = \(projectID); }\n").write(
    to: project.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)
func buildable(_ id: String, _ name: String, _ file: String) -> String {
  "<BuildableReference BuildableIdentifier=\"primary\" BlueprintIdentifier=\"\(id)\" BuildableName=\"\(file)\" BlueprintName=\"\(name)\" ReferencedContainer=\"container:ComponentVisualReview.xcodeproj\"/>"
}
let appRef = buildable(hostTarget, "ComponentVisualHost", "ComponentVisualHost.app")
let testRef = buildable(testTarget, "ComponentVisualUITests", "ComponentVisualUITests.xctest")
let scheme = """
  <?xml version="1.0" encoding="UTF-8"?>
  <Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="NO" buildForAnalyzing="YES">\(appRef)</BuildActionEntry>
  <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">\(testRef)</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">\(testRef)</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">\(appRef)</BuildableProductRunnable></LaunchAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  </Scheme>
  """
try scheme.write(
  to: schemes.appendingPathComponent("ComponentVisualReview.xcscheme"), atomically: true,
  encoding: .utf8)
print("Xcode project: \(project.path)")
if prepareOnly { exit(0) }

func run(_ arguments: [String], log: URL, timeout: TimeInterval = 900) throws -> Int32 {
  _ = files.createFile(atPath: log.path, contents: nil)
  let handle = try FileHandle(forWritingTo: log)
  defer { try? handle.close() }
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
  process.arguments = arguments
  process.standardOutput = handle
  process.standardError = handle
  let ended = DispatchSemaphore(value: 0)
  process.terminationHandler = { _ in ended.signal() }
  try process.run()
  if ended.wait(timeout: .now() + timeout) == .timedOut {
    print(
      "Timed out after \(Int(timeout))s: \(arguments.prefix(2).joined(separator: " ")); log: \(log.path)"
    )
    if process.isRunning { process.terminate() }
    if ended.wait(timeout: .now() + 5) == .timedOut && process.isRunning {
      kill(process.processIdentifier, SIGKILL)
    }
    process.waitUntilExit()
    return 124
  }
  return process.terminationStatus
}
let runID = buildStamp
let result = output.appendingPathComponent("Results-\(runID).xcresult")
let log = output.appendingPathComponent("Tests-\(runID).log")
var command = [
  "xcodebuild", "test", "-project", project.path, "-scheme", "ComponentVisualReview",
  "-destination", "platform=iOS Simulator,id=\(option("--simulator")!)", "-derivedDataPath",
  output.appendingPathComponent("DerivedData").path, "-resultBundlePath", result.path,
  "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO",
]
if args.contains("--phone-only") {
  command.append("SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG SDK_PHONE_ACCEPTANCE")
}
let classPattern = try NSRegularExpression(pattern: #"final\s+class\s+(\w+)\s*:\s*ReviewTestCase"#)
let methodPattern = try NSRegularExpression(pattern: #"\bfunc\s+(test[A-Za-z0-9_]+)\s*\("#)
var discoveredTests = Set<String>()
for file in testFiles {
  let source = try String(contentsOf: file, encoding: .utf8)
  guard let match = classPattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
    let classRange = Range(match.range(at: 1), in: source) else { continue }
  let className = String(source[classRange])
  for method in methodPattern.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
    if let range = Range(method.range(at: 1), in: source) { discoveredTests.insert(className + "/" + source[range]) }
  }
}
var expectedTests = discoveredTests
if args.contains("--phone-only") {
  for test in ["ReviewMapTests/testNativeMapAccessibleTextKeepsMarkersVisible", "ReviewLayoutTests/testAccessibleTextRemainsScrollable"] {
    expectedTests.remove(test)
    command.append("-skip-testing:ComponentVisualUITests/" + test)
  }
}
var requestedTests = option("--only-testing")
if let suite = option("--suite") {
  guard requestedTests == nil, ["quick", "full"].contains(suite) else {
    print("Use --suite quick|full or --only-testing, not both")
    exit(2)
  }
  if suite == "quick" {
    requestedTests = [
      "testCatalogAndEngineIntegrity",
      "testRepresentativeAdaptiveCompositions",
      "testScenarioNavigationAndVariants",
      "testDisplayConditionsPreserveProgramState",
    ].map { "ReviewCatalogTests/" + $0 }.joined(separator: ",")
  }
}
if let only = requestedTests {
  let selections = only.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter
  { !$0.isEmpty }
  guard !selections.isEmpty else {
    print("Empty --only-testing selection")
    exit(2)
  }
  expectedTests = []
  for selection in selections {
    let matches = selection.contains("/")
      ? discoveredTests.filter { $0 == selection } : discoveredTests.filter { $0.hasPrefix(selection + "/") }
    guard !matches.isEmpty else {
      print("Unknown native test selection: \(selection)")
      exit(2)
    }
    expectedTests.formUnion(matches)
  }
  for selection in selections {
    command.append("-only-testing:ComponentVisualUITests/" + selection)
  }
}
print("Expected native tests: \(expectedTests.sorted().joined(separator: ", "))")
// Stable system chrome on the selected test simulator. This is simulator
// configuration, not modification of captured pixels.
let simulator = option("--simulator")!
let boot = try run(
  ["simctl", "bootstatus", simulator, "-b"],
  log: output.appendingPathComponent("Device-\(runID).log"), timeout: 120)
guard boot == 0 else {
  print("Simulator did not become ready")
  exit(boot)
}
let chrome = try run(
  [
    "simctl", "status_bar", simulator, "override", "--time", "09:41", "--batteryState", "charged",
    "--batteryLevel", "100",
  ], log: output.appendingPathComponent("StatusBar-\(runID).log"), timeout: 30)
guard chrome == 0 else {
  print("Could not standardize simulator status bar")
  exit(chrome)
}
// Install fresh copies of this review host and its runner. Both are disposable
// test apps on the selected simulator; other apps and simulator state remain.
for bundle in ["dev.swiftui.component-review.uitests.xctrunner", "dev.swiftui.component-review"] {
  let reset = try run(
    ["simctl", "uninstall", simulator, bundle],
    log: output.appendingPathComponent("Reset-\(bundle)-\(runID).log"), timeout: 30)
  guard reset == 0 else {
    print("Could not remove the previous disposable test app: \(bundle)")
    exit(reset)
  }
}
var status = try run(command, log: log, timeout: TimeInterval(option("--timeout") ?? "3600") ?? 3600)
let transcript = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
let missingTests = expectedTests.filter { selection in
  let parts = selection.split(separator: "/")
  return !transcript.contains(".\(parts[0]) \(parts[1])]' started.")
}
if !missingTests.isEmpty {
  print(
    "Native test coverage incomplete; not executed: \(missingTests.sorted().joined(separator: ", ")). A stale or partial runner is not acceptance."
  )
  if status == 0 { status = 2 }
}
_ = try? run(
  ["simctl", "status_bar", simulator, "clear"],
  log: output.appendingPathComponent("StatusBarClear-\(runID).log"), timeout: 30)
print("XCUITest exit: \(status); log: \(log.path); result: \(result.path)")
if files.fileExists(atPath: result.path) {
  let attachments = output.appendingPathComponent("Attachments-\(runID)")
  let exportStatus = try run(
    [
      "xcresulttool", "export", "attachments", "--path", result.path, "--output-path",
      attachments.path,
    ], log: output.appendingPathComponent("Export-\(runID).log"), timeout: 120)
  print("Native screenshot export: \(exportStatus); \(attachments.path)")
}
try result.path.write(
  to: output.appendingPathComponent("last-result-path.txt"), atomically: true, encoding: .utf8)
if let text = try? String(contentsOf: log, encoding: .utf8) {
  for line in text.components(separatedBy: "\n").filter({
    $0.contains("error:") || $0.contains("Test Case") || $0.contains("TEST SUCCEEDED")
      || $0.contains("TEST FAILED")
  }).suffix(35) { print(line) }
}
if args.contains("--package-tests") {
  let packageLog = output.appendingPathComponent("PackageTests-\(runID).log")
  let packageStatus = try run(
    [
      "swift", "test", "--package-path", package.path, "--scratch-path",
      output.appendingPathComponent("PackageTests").path,
    ], log: packageLog)
  print("SDK package tests exit: \(packageStatus); log: \(packageLog.path)")
  if let text = try? String(contentsOf: packageLog, encoding: .utf8) {
    for line in text.components(separatedBy: "\n").filter({
      $0.contains("error:") || $0.contains("Executed ")
    }).suffix(15) { print(line) }
  }
  if status == 0 { status = packageStatus }
}
exit(status)
