//
//  ViewContainer.swift
//  

import Foundation
import SwiftUI
import Combine

public struct ViewContainer: Hashable {
    let id: String
    let reuseId: String
    let configuration: UIContentConfiguration
    
    init<Content: View>(id: String, view: Content) {
        self.id = id
        self.reuseId = String(describing: type(of: view)) + id
        //if #available(iOS 16, *) {
        //    configuration = UIHostingConfiguration { view }.margins(.all, 0)
        //} else {
        
        //in iOS 18 view state is dropped when cell is presented, this custom hosting controller prevents it
        configuration = UIHostingConfigurationBackport(content: { view.ignoresSafeArea() }).margins(.all, 0)
        //}
    }
    
    public static func == (lhs: ViewContainer, rhs: ViewContainer) -> Bool { lhs.hashValue == rhs.hashValue }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public extension View {
    
    @MainActor func inContainer(id: String? = nil) -> ViewContainer {
        let id = String(describing: type(of: self)) + (id ?? "")
        return ViewContainer(id: id, view: self.id(id))
    }
}
