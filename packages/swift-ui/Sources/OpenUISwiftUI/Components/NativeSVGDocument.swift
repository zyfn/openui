import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct NativeSVGDocument {
    let markup: String
    let ratio: CGFloat
    static func parse(_ source: String) -> NativeSVGDocument? {
        guard source.utf8.count <= 1_000_000, !source.localizedCaseInsensitiveContains("<!DOCTYPE"),
              !source.localizedCaseInsensitiveContains("<!ENTITY") else { return nil }
        let reader = SVGReader()
        let parser = XMLParser(data: Data(source.utf8)); parser.shouldResolveExternalEntities = false; parser.delegate = reader
        guard parser.parse(), reader.valid, let ratio = reader.ratio else { return nil }
        return NativeSVGDocument(markup: source, ratio: ratio)
    }
}
private final class SVGReader: NSObject, XMLParserDelegate {
    var valid = true
    var ratio: CGFloat?
    private var root = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        let name = elementName.lowercased().split(separator: ":").last.map(String.init) ?? ""
        if !root {
            root = true
            guard name == "svg", let box = attributes["viewBox"] else { valid = false; return }
            let tokens = box.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            let values = tokens.compactMap { Double($0) }
            guard tokens.count == 4, values.count == 4, values.allSatisfy(\.isFinite), values[2] > 0, values[3] > 0 else { valid = false; return }
            if let mode = attributes["preserveAspectRatio"], mode.contains("slice") || mode.contains("none") { valid = false }
            let aspect = values[2] / values[3]
            guard aspect.isFinite, aspect > 0 else { valid = false; return }
            ratio = CGFloat(aspect)
        }
        if name.hasPrefix("animate") || ["script", "foreignobject", "iframe", "object", "embed", "audio", "video", "set", "discard"].contains(name) { valid = false }
        for (key, value) in attributes {
            let key = key.lowercased()
            if key.hasPrefix("on") { valid = false }
            if key == "href" || key == "xlink:href" {
                if !value.hasPrefix("#") && !value.hasPrefix("data:image/") { valid = false }
            }
        }
    }
}

