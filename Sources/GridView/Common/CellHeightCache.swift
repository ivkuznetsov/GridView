//
//  CellHeightCache.swift
//  
//
//  Created by Ilya Kuznetsov on 19/09/2023.
//

import Foundation

public final class CellHeightCache {
    
    private struct Key: Hashable {
        let id: Int
        let width: CGFloat
    }
    
    private static let shared = CellHeightCache()
    
    private var sizes: [Key:CGFloat] = [:]
    private var lock: pthread_rwlock_t
    
    private init() {
        lock = pthread_rwlock_t()
        pthread_rwlock_init(&lock, nil)
    }
    
    public static func size<ID: Hashable>(id: ID, width: CGFloat, calculate: ()->CGFloat) -> CGFloat {
        shared.size(id: id, width: width, calculate: calculate)
    }
    
    private func size<ID: Hashable>(id: ID, width: CGFloat, calculate: ()->CGFloat) -> CGFloat {
        let key = Key(id: id.hashValue, width: width)
        
        pthread_rwlock_wrlock(&lock)
        defer { pthread_rwlock_unlock(&lock) }
        if let result = sizes[key] {
            return result
        }
        let result = calculate()
        sizes[key] = result
        return result
    }
    
    deinit {
        pthread_rwlock_destroy(&lock)
    }
}
