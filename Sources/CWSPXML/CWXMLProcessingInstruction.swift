//
//  CWXMLProcessingInstruction.swift
//  CWXML
//
//  Created by Colin Wilson on 16/11/2017.
//  Copyright © 2017 Colin Wilson. All rights reserved.
//

import Foundation

public class CWXMLProcessingInstruction: CWXMLNode {
    public let target: String
    public let data: String?
    
    public init (target: String, data: String?) {
        self.target = target
        self.data = data
        super.init(nodeType: .ProcessingInstruction)
    }
    
    public override var stringValue: String? {
        return data
    }
}
