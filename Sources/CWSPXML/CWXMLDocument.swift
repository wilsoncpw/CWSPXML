//
//  CWXMLDocument.swift
//  XMLTest
//
//  Created by Colin Wilson on 12/10/2017.
//  Copyright © 2017 Colin Wilson. All rights reserved.
//
//  Why ???
//
//  Because XMLDocument doesn't work on iOS!

import Foundation




public class CWXMLDocument: CWXMLNode {
    private (set) var comments = [CWXMLComment] ()
    private (set) var processingInstructions = [CWXMLProcessingInstruction] ()
    private (set) public var rootElement: CWXMLElement?
    
    private (set) public var url: URL?
    
    public let isStandalone = true
    public let characterEncoding : String? = "UTF-8"
    
    required public init () {
        super.init(nodeType: .Document)
    }
    
    convenience public init (rootElementName: String, rootElementAttributes: [String: String]?, rootElementText: String?) {
        self.init()
        let elem = CWXMLElement (name: rootElementName)
        elem.setAttributesAndNamespaces(rootElementAttributes)
        elem.text = rootElementText
        internalSetRootElement(elem: elem)
    }
    
    public func noteURL (url: URL?) {
        self.url = url
    }
    
    func internalSetRootElement (elem: CWXMLElement) {
        rootElement = elem
        elem.parent = self
        addChild(node: elem)
    }
    
    @discardableResult public func setRootElement (elem: CWXMLElement?) throws -> CWXMLElement? {
        guard let elem = elem else {
            rootElement = nil
            return nil
        }
        
        if let eDoc = elem.document, eDoc !== self {
            if rootElement == nil {
                eDoc.rootElement = nil
            } else {
                throw CWXMLError.WrongDocument
            }
        }
        
        internalSetRootElement(elem: elem)
        return elem
    }
    
    @discardableResult public func setNewRootElement (name: String, attributes: [String: String]?, text: String?) -> CWXMLElement {
        let elem = CWXMLElement (name: name)
        elem.setAttributesAndNamespaces(attributes)
        elem.text = text
        internalSetRootElement(elem: elem)
        return elem
    }
    
    public override var XML: String {
        get {
            var rv: String
            if let characterEncoding = characterEncoding {
                rv = "<?xml version=\"1.0\" encoding=\"" + characterEncoding + "\"?>\n"
            } else {
                rv = "<?xml version=\"1.0\"?>\n"
             }
            
            if let children = children {
                for child in children {
                    rv += child.XML
                }
            }
            
            return rv
        }
    }
    
    public func addComment (comment: CWXMLComment) {
        comments.append(comment)
        addChild(node: comment)
    }
    
    public func addProcessingInstruction (instruction: CWXMLProcessingInstruction) {
        processingInstructions.append(instruction)
        addChild(node: instruction)
    }
    
    @discardableResult public func addChildElement (_ parent: CWXMLElement, elem: CWXMLElement) throws ->CWXMLElement {
        try parent.appendChildElement(elem: elem)
        return elem
    }
    
    public func firstElement (forLocalName name: String, namespaceURI: String?, recurse: Bool) -> CWXMLElement? {
        guard let root = rootElement else {
            return nil
        }
        
        return root.firstElement(forLocalName:name, namespaceURI:namespaceURI, recurse:recurse)
    }
    
    @discardableResult public func addNewChildElement (parent: CWXMLElement, name: String, attributes: [String: String]?, text: String?) -> CWXMLElement {
        let elem = CWXMLElement (name: name)
        elem.setAttributesAndNamespaces(attributes)
        elem.text = text
        parent.internalAppendChild(elem: elem)
        return elem
    }
}
