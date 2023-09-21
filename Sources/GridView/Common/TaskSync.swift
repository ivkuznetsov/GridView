//
//  TaskSync.swift
//  
//
//  Created by Ilya Kuznetsov on 21/09/2023.
//

import Foundation

actor TaskSync {
    
    private var task: Task<Any, Error>?
    
    func run<Success>(_ block: @Sendable @escaping () async throws -> Success) async throws -> Success {
        task = Task { [task] in
            _ = await task?.result
            return try await block() as Any
        }
        return try await task!.value as! Success
    }
}
