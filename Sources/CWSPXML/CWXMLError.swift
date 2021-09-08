//
//  CWXMLError.swift
//  CWXML
//
//  Created by Colin Wilson on 17/11/2017.
//  Copyright © 2017 Colin Wilson. All rights reserved.
//

import Foundation

public enum CWXMLError: Error {
    case WrongDocument
    case ChildNotFound
    case CantInsertAncestor
    case NamespaceError
}

