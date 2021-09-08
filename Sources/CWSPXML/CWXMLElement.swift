//
//  CWXMLElement.swift
//  XMLTest
//
//  Created by Colin Wilson on 12/10/2017.
//  Copyright © 2017 Colin Wilson. All rights reserved.
//

import Foundation

//=====================================================================================
// CWXMLElement class
open class CWXMLElement: CWXMLNode {
    weak var parent: CWXMLNode?
    public let name: String             // Qualified name
    private (set) public var attributes : [String: String]?
    private (set) public var namespaces: [String: String]?
    private (set) public var comments = [CWXMLComment] ()

    public var text: String?
    private (set) public var childElements : [CWXMLElement]?
    
    private var _uri: String?
    private var _prefix: String?
    private var _localName: String?
    

    //-----------------------------------------------------------------------------------
    // init - main initializer
    public required init (name: String) {
        self.name = name
        super.init(nodeType: .Element)
    }
    
    //-----------------------------------------------------------------------------------
    // Get & cache the prefix. Eg. if the name is wsdl:types, return 'wsdl'
    public var prefix: String {
        if _prefix == nil {
            let px = splitQName(qname: name)
            _prefix = px.prefix
            _localName = px.localName
        }
        return _prefix!
    }
    
    //-----------------------------------------------------------------------------------
    // Get the namespace URI by looking up the prefix in namespaces.  Eg.  if the prefix
    // is 'wsdl', look this up in the namespaces (and the parents namespaces, etc.) to
    // get http://schemas.xmlsoap.org/wsdl/
    public var namespaceUri: String? {
        if _uri == nil {
            _uri = namespace (forPrefix: prefix)
        }
        return _uri
    }
    
    //-----------------------------------------------------------------------------------
    // Get and return the local name.  Eg. If the name is 'wsdl:types' return 'types'
    public var localName: String {
        let _ = prefix
        return _localName ?? ""
    }
    
    //-----------------------------------------------------------------------------------
    // Return the element's parent element - or nil
    public var parentElement: CWXMLElement? {
        return parent as? CWXMLElement ?? nil
    }
    
    //-----------------------------------------------------------------------------------
    // Return the element's document
    public var document: CWXMLDocument? {
        var p = self
        
        while let px = p.parent as? CWXMLElement {
            p = px
        }
        return p.parent as? CWXMLDocument ?? nil
    }
    
    //-----------------------------------------------------------------------------------
    // Append a child element - internal version doesn't check that the element is in our
    // our document, etc.
    internal func internalAppendChild (elem: CWXMLElement) {
        if childElements == nil {
            childElements = [CWXMLElement] ()
        }

        // Append it to both our childElements array and the base node's children array
        childElements!.append(elem)
        addChild(node: elem)
        
        // Remove namespaces from the child where the same namespace is defined in the parent
        if let elemNamespaces = elem.namespaces {
            for ns in elemNamespaces {
                if self.namespace(forPrefix: ns.key) == ns.value {
                    if let idx = elem.namespaces!.index(forKey: ns.key) {
                        elem.namespaces!.remove(at: idx)
                    }
                }
            }
        }
        elem.parent = self
    }
    
   
    //-----------------------------------------------------------------------------------
    // Return true if we're an ancestor of the given element
    public func isAncestorOf (_ elem: CWXMLElement)->Bool {
        var p = elem
        
        while let pElem = p.parentElement {
            if pElem === self {
                return true
            }
            p = pElem
        }
        return false
    }
    
    //-----------------------------------------------------------------------------------
    // Append a child element.  Return the element for convenience.
    @discardableResult public func appendChildElement (elem: CWXMLElement) throws -> CWXMLElement {
        func _appendChild (elem: CWXMLElement) throws {
            
            // Before removing the elem from it's old parent, check that it's not
            // our ancestor.  Otherwise we're fucked!
            if elem.isAncestorOf (self) {
                throw CWXMLError.CantInsertAncestor
            }
            
            // Remove the elem from its parent's children
            if let eParent = elem.parentElement {
                try eParent.removeChild (elem: elem)
            }
            internalAppendChild(elem: elem)
        }
        
        // If we have a document, and so does elem, check that they match
        if let document = document {
            if let eDoc = elem.document {
                guard document === eDoc else {
                    throw CWXMLError.WrongDocument
                }
            }
            try _appendChild(elem: elem)
        } else {
            // We don't have a document - check that the elem doesn't either
            guard elem.document == nil else {
                throw CWXMLError.WrongDocument
            }
            try _appendChild(elem: elem)
        }
        return elem
    }
    
    @discardableResult public func removeChild (elem: CWXMLElement) throws ->CWXMLElement {
        if childElements == nil {
            throw CWXMLError.ChildNotFound
        }
        guard let idx = childElements!.firstIndex (of: elem) else {
            throw CWXMLError.ChildNotFound
        }
        
        removeChild(node: elem)
        
        elem.parent = nil
        return childElements!.remove(at: idx)
    }
    
    //-----------------------------------------------------------------------------------
    public override var XML: String {
        get {
            if attributes == nil && children == nil && text == nil && namespaces == nil {
                return "<" + name + "/>"
            }
            
            var rv: String
            
            // 1.  Opening tag - with attributes
            if namespaces != nil || attributes != nil {
                rv = "<" + name
                
                if let namespaces = namespaces {
                    for key in namespaces.keys {
                        if key == "" {
                            rv += " xmlns=\"" + namespaces [key]! + "\""
                        } else {
                            rv += " xmlns:" + key + "=\"" + namespaces [key]! + "\""
                        }
                    }
                }
                
                if let attributes = attributes {
                    for key in attributes.keys {
                        rv += " " + key + "=\"" + attributes [key]! + "\""
                    }
                }
                
                if text == nil && children == nil {
                    return rv + "/>"
                }
                else {
                    rv += ">"
                }
            }
            else {
                rv = "<" + name + ">"
            }
            
            // 2.  Data
            if let text = text {
                rv += stringByEncodingXMLEntities(text)
            }
            
            // 3.  Children
            
            if let children = children {
                for child in children {
                    rv += child.XML
                }
            }
            
            // 4.  Closing tag
            return rv + "</" + name + ">"
        }
    }
    
    //-----------------------------------------------------------------------------------
    open override var stringValue: String? {
        if let st = text?.trimmingCharacters(in: ["\n", "\t"]) {
            return st.isEmpty ? nil : st
        }
        return nil
    }
    
    //-----------------------------------------------------------------------------------
    public func addComment (comment: CWXMLComment) {
        comments.append(comment)
        addChild(node: comment)
    }
}

//=====================================================================================
// CWXMLElement extension with attributey stuff
public extension CWXMLElement {
   
    //-----------------------------------------------------------------------------------
    // init - initialze with attributes & namespaces
    convenience init (name: String, attributes: [String: String]) {
        self.init(name: name)
        setAttributesAndNamespaces (attributes)
    }
    
    //-----------------------------------------------------------------------------------
    func attribute (forName name: String) -> String? {
        return attributes? [name]
    }
    
    //-----------------------------------------------------------------------------------
    func setAttribute (name: String, value: String) {
        if attributes == nil {
            attributes = [String: String] ()
        }
        attributes! [name] = value
    }
    
    //-----------------------------------------------------------------------------------
    internal func setAttributesAndNamespaces (_ values: [String: String]?) {
        
        guard let attributes = values else {
            self.attributes = nil
            self.namespaces = nil
            return
        }
        
        var ns = [String: String] ()
        var attr = [String: String] ()
        
        // Attributes with the prefix 'xmlns' are really namespaces - so split them into a separate array
        attributes.forEach() {
            body in
            let s = splitQName(qname: body.key)
            
            if s.localName == "xmlns" && s.prefix.isEmpty {
                ns [""] = body.value
            } else if s.prefix == "xmlns" {
                ns [s.localName] = body.value
            } else {
                attr [body.key] = body.value
            }
        }
        
        if attr.count > 0 {
            self.attributes = attr
        } else {
            self.attributes = nil
        }
        
        if ns.count > 0 {
            self.namespaces = ns
        } else {
            self.namespaces = nil
        }
    }
}

//=====================================================================================
// CWXMLElement extension with namespacey stuff
public extension CWXMLElement {
    
    //-----------------------------------------------------------------------------------
    // return the namespaceURI for a given prefix.  Search in our namespaces, then our
    // parent's. etc.
    func namespace (forPrefix prefix: String) -> String? {
        
        //------------------------  This probably works - but not very clear! ----
        // return namespaces? [prefix] ?? parentElement?.namespace(forPrefix:prefix)
        
        var rv = namespaces? [prefix]
        if rv == nil {
            rv = parentElement?.namespace(forPrefix: prefix)
        }
        return rv
    }
    
    //-----------------------------------------------------------------------------------
    // Internal func to set namespaces all in one go.
    internal func setNamespaces (namespaces: [String: String]?) {
        if namespaces != nil && namespaces!.count > 0 {
            self.namespaces = namespaces
        } else {
            self.namespaces = nil
        }
    }
    
    
    //-----------------------------------------------------------------------------------
    func resolveNamespace (forName qname: String, defaultPrefix: String = "") -> String? {
        let s = qname.components(separatedBy:":")
        
        if s.count > 1 {
            return namespace(forPrefix:s [0])
        }
        return namespace(forPrefix:defaultPrefix)
    }
    
    //-----------------------------------------------------------------------------------
    func elements(forLocalName name: String, namespaceUri: String?) -> [CWXMLElement] {
        guard let children = childElements else {
            return [CWXMLElement] ()
        }
        
        return children.filter() {
            elem in
            return (namespaceUri == nil || (elem.namespaceUri != nil && elem.namespaceUri! == namespaceUri!)) && name == elem.localName
        }
    }
    
    //-----------------------------------------------------------------------------------
    func elements(forName name: String) -> [CWXMLElement] {
        let s = name.components(separatedBy: ":")
        
        if s.count >= 2 {
            guard let namespaces = namespaces, let namespaceUri = namespaces [s [0]] else {
                return [CWXMLElement] ()
            }
            return elements(forLocalName: s [1], namespaceUri: namespaceUri)
        }
        
        guard let children = childElements else {
            return [CWXMLElement] ()
        }
        
        return children.filter() {
            elem in
            elem.name == name
        }
    }
    
    //-----------------------------------------------------------------------------------
    func firstElement (forLocalName name: String, namespaceURI: String?, recurse: Bool) -> CWXMLElement? {
        guard let children = childElements else {
            return nil
        }
        
        var rv = children.first(where: ) {
            elem in
            return elem.localName == name && (namespaceURI == nil || elem.namespaceUri == namespaceURI)
        }
        
        if rv == nil && recurse {
            for child in children {
                rv = child.firstElement(forLocalName: name, namespaceURI: namespaceURI, recurse: true)
                if rv != nil {
                    break
                }
            }
        }
        return rv
    }
}
