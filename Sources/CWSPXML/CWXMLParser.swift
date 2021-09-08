//
//  CWXMLParser.swift
//  XMLTest
//
//  Created by Colin Wilson on 10/10/2017.
//  Copyright © 2017 Colin Wilson. All rights reserved.
//

import Foundation

enum CWXMLParserError: Error {
    case internalError (innerError: Error?)
    case parserBusy
    case errorLoadingURL
    case documentStartedTwice
    case documentNotStarted
    case prefixMappingNotStarted
    case noCurrentElement
}

public class CWXMLParser {
    
    private let parser : XMLParser
    private var error: CWXMLParserError?
    private var busy = false
    fileprivate var url: URL?
    
    public init (data: Data) {
        parser = XMLParser (data: data)
    }
    
    public init (stream: InputStream) {
        parser = XMLParser (stream: stream)
    }
    
    public init (url: URL) throws {
        if let parser = XMLParser (contentsOf: url) {
            self.parser = parser
            self.url = url
        } else {
            throw CWXMLParserError.errorLoadingURL
        }
    }
    
    public func parse (docType: CWXMLDocument.Type = CWXMLDocument.self) throws -> CWXMLDocument {
        guard !busy else {
            throw CWXMLParserError.parserBusy
        }
        busy = true
        defer {
            busy = false
        }
        let delegate = CWXMLParserDelegate (parser: self)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = true
        
        delegate._currentDocument = nil
        delegate.currentDocType = docType
        parser.parse()
        
        if let doc = delegate.doc {
            return doc
        }
        
        throw error!
    }
    
    fileprivate func handleError (_ error: CWXMLParserError) {
        self.error = error
        parser.abortParsing()
    }
}

class CWXMLParserDelegate: NSObject, XMLParserDelegate {
    
    let p : CWXMLParser
    private var _currentElement: CWXMLElement?
    fileprivate var _currentDocument: CWXMLDocument?
    fileprivate var currentDocType: CWXMLDocument.Type = CWXMLDocument.self

    private var currentNamespaces : [String: String]?


    init (parser: CWXMLParser) {
        p = parser
    }
    
    func parserDidStartDocument(_ parser: XMLParser) {
        guard _currentDocument == nil else {
            p.handleError (.documentStartedTwice)
            return
        }
        _currentDocument = currentDocType.init ()
        _currentDocument!.noteURL (url: p.url)
        _currentElement = nil
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        if _currentDocument == nil {
            p.handleError(.documentNotStarted)
        }
    }
    
    
    func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) {
        
    }
    
    
    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?) {
        
    }
    
    
    func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?) {
        
    }
    
    
    func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) {
        
    }
    
    
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        
    }
    
    
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        
    }
    
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard let doc = doc else {
            return
        }
        
        var name = qName
        if name == nil {
            name = elementName
        }
        
        let elem = CWXMLElement (name: name!)
        
        elem.setAttributesAndNamespaces (attributeDict)
        if let currentElement = _currentElement {
            
            // Get the current namespaces that the parent doesn't know about
            let namespaces = currentNamespaces?.filter() {
                ns in
                let parentNS = currentElement.namespace(forPrefix: ns.key)
                return parentNS == nil || parentNS! != ns.value
            }
            elem.setNamespaces(namespaces: namespaces)
            currentElement.internalAppendChild(elem: elem)

        }
        else {
            elem.setNamespaces(namespaces: currentNamespaces)
            doc.internalSetRootElement(elem: elem)
        }
        
        if let namespaceURI = namespaceURI, !namespaceURI.isEmpty {
            do {
                guard let namespaceUri = elem.namespaceUri else {
                    throw CWXMLError.NamespaceError
                }
                
                if namespaceURI != namespaceUri {
                    throw CWXMLError.NamespaceError
                }
                
            } catch let e {
                p.handleError(.internalError (innerError: e))
                return
            }
        }
    
        _currentElement = elem
    }
    
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let e = currentElement else {
            return
        }
        
        _currentElement = e.parentElement
    }
    
    
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        if currentNamespaces == nil {
            currentNamespaces = [String: String] ()
        }
        
        currentNamespaces! [prefix] = namespaceURI
    }
    
    
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) {
        if currentNamespaces == nil {
            p.handleError(.prefixMappingNotStarted)
            return
        }
        
        if currentNamespaces!.removeValue(forKey: prefix) == nil {
            p.handleError(CWXMLParserError.prefixMappingNotStarted)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let currentElement = currentElement else {
            p.handleError(.noCurrentElement)
            return
        }
        
        if currentElement.text == nil {
            let st = string.trimmingCharacters(in: [" ", "\n"])
            if !st.isEmpty {
                currentElement.text = st
            }
        } else {
            currentElement.text!.append (string)
        }
    }
    
    
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
        
    }
    
    
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
        guard let doc = doc else {
            return
        }
        
        doc.addProcessingInstruction(instruction: CWXMLProcessingInstruction (target: target, data: data))
    }
    
    
    func parser(_ parser: XMLParser, foundComment comment: String) {
        guard let doc = doc else {
            return
        }
        if let elem = _currentElement {
            elem.addComment(comment: CWXMLComment (value: comment))
        } else {
            doc.addComment(comment: CWXMLComment (value: comment))
        }
    }
    
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        
    }
    
    
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        return nil
    }
    
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        
    }
    
    
    
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        
    }
    
    fileprivate var doc: CWXMLDocument? {
        if _currentDocument == nil {
            p.handleError(.documentNotStarted)
        }
        return _currentDocument
    }
    
    private var currentElement: CWXMLElement? {
        if _currentElement == nil {
            p.handleError(.noCurrentElement)
        }
        return _currentElement
    }
    
}
