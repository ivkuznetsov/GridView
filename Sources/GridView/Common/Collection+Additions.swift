//
//  File.swift
//  
//
//  Created by Ilya Kuznetsov on 21/09/2023.
//

import Foundation

extension Collection where Indices.Iterator.Element == Index {
    
    subscript (safe index: Index) -> Iterator.Element? {
        indices.contains(index) ? self[index] : nil
    }
}
