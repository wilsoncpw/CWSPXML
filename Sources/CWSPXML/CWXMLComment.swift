//
//  CWXMLComment.swift
//  CWXML
//
//  Created by Colin Wilson on 16/11/2017.
//  Copyright © 2017 Colin Wilson. All rights reserved.
//

import Foundation

public class CWXMLComment: CWXMLNode {
    public let value: String
    
    public init (value: String) {
        self.value = value
        super.init(nodeType: .Comment)
    }
    
    public override var stringValue: String? {
        return value
    }
}
