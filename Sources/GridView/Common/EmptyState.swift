//
//  EmptyState.swift
//  
//
//  Created by Ilya Kuznetsov on 21/09/2023.
//

import Foundation
import SwiftUI

public struct EmptyState {
    let view: AnyView
    let isPresented: (()->Bool)?
    
    public init<EmptyView: View>(_ view: ()->EmptyView, isPresented: (()->Bool)? = nil) {
        self.view = AnyView(view())
        self.isPresented = isPresented
    }
    
    @ViewBuilder
    func viewIfNeeded(_ itemsCount: Int) -> some View {
        if isPresented?() == true || (isPresented == nil && itemsCount == 0) {
            view
        }
    }
}
