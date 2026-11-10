import CryptoKit
import Foundation
import XCTest
import OpenUILang
@testable import OpenUISwiftUI

final class AgentExampleContractTests: XCTestCase {
  private var directory: URL {
    var root=URL(fileURLWithPath:#filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("examples/agent-cases")
  }
  @MainActor func testEightCanonicalExamplesMatchTheirManifestAndActualComponentSignatures() throws {
    let spec=try LibrarySpec(jsonString:String(contentsOf:directory.appendingPathComponent("test-library-spec.json"),encoding:.utf8))
    let standard=try OpenUIStandardComponents.library().toSpec()
    let expandedSlots:Set<String>=["Card","TabItem","AccordionItem"]
    for component in standard.components where !expandedSlots.contains(component.name) {
      XCTAssertEqual(spec.components.first { $0.name==component.name }?.signature,component.signature,component.name)
    }
    let schema=compileLibrarySchema(spec)
    let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as! [String:Any]
    let cases=manifest["cases"] as! [[String:Any]]
    XCTAssertEqual(cases.map { $0["number"] as! Int },Array(1...8))
    for item in cases {
      let file=item["file"] as! String
      let data=try Data(contentsOf:directory.appendingPathComponent(file))
      XCTAssertEqual(SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined(),item["sha256"] as? String,file)
      let source=String(decoding:data,as:UTF8.self)
      XCTAssertTrue(source.hasPrefix("root = "),file)
      let batch=createParser(schema:schema).parse(source)
      XCTAssertTrue(batch.meta.errors.isEmpty,"\(file): \(batch.meta.errors)")
      XCTAssertTrue(batch.meta.unresolved.isEmpty,file)
      XCTAssertTrue(batch.meta.orphaned.isEmpty,file)
      let stream=createStreamingParser(schema:schema)
      let chars=Array(source)
      for start in stride(from:0,to:chars.count,by:73) {
        stream.push(String(chars[start..<min(chars.count,start+73)]))
      }
      let result=stream.getResult(complete:true)
      XCTAssertEqual(result.root,batch.root,file)
      XCTAssertTrue(result.meta.errors.isEmpty,file)
    }
  }

  @MainActor func testVisualExampleCanPresentItsFirstCardBeforeTheRestOfTheGroupArrives() throws {
    let spec=try LibrarySpec(jsonString:String(contentsOf:directory.appendingPathComponent("test-library-spec.json"),encoding:.utf8))
    let state=OpenUIState(schema:compileLibrarySchema(spec))
    let source=try String(contentsOf:directory.appendingPathComponent("case-01-explore-scene-discovery.openui"),encoding:.utf8)
    func find(_ value:Value) -> EvaluatedElement? {
      switch value {
      case .element(let e):
        if e.typeName=="VisualCardBlock" { return e }
        return e.props.compactMap { find($0.1) }.first
      case .array(let a): return a.compactMap(find).first
      default:return nil
      }
    }
    var observed=false
    for line in source.split(separator:"\n",omittingEmptySubsequences:false) {
      state.push(String(line)+"\n")
      if let root=state.root,let block=find(.element(root)),PropValue.children(block,"items").count==1 {
        XCTAssertTrue(NativeLayoutContract.ready(block.sourceReadiness,fields:NativeLayoutContract.fields(for:"VisualCardBlock")))
        XCTAssertEqual(block.sourceReadiness["items"].expectedCount,4)
        XCTAssertFalse(state.isComplete)
        observed=true;break
      }
    }
    XCTAssertTrue(observed,"The first authored card must not wait for all four inline items")
  }

  @MainActor func testGalleryExampleSeparatesKnownColumnsFromImageRecordArrival() throws {
    let spec=try LibrarySpec(jsonString:String(contentsOf:directory.appendingPathComponent("test-library-spec.json"),encoding:.utf8))
    let state=OpenUIState(schema:compileLibrarySchema(spec))
    let source=try String(contentsOf:directory.appendingPathComponent("case-02-explore-visual-preview-ticket-booking.openui"),encoding:.utf8)
    func find(_ value:Value) -> EvaluatedElement? {
      switch value {
      case .element(let e):
        if e.typeName=="ImageGallery",NativeValue.array(PropValue.value(e,"images")).count==1 { return e }
        return e.props.compactMap { find($0.1) }.first
      case .array(let a):return a.compactMap(find).first
      default:return nil
      }
    }
    var observed=false
    for line in source.split(separator:"\n",omittingEmptySubsequences:false) {
      state.push(String(line)+"\n")
      if let root=state.root,let gallery=find(.element(root)) {
        let readiness=gallery.sourceReadiness["images"]
        XCTAssertEqual(readiness.expectedCount,2)
        XCTAssertTrue(NativeLayoutContract.collectionShapeReady(readiness,count:1))
        XCTAssertTrue(readiness[0]["src"].complete)
        observed=true;break
      }
    }
    XCTAssertTrue(observed)
  }
}
