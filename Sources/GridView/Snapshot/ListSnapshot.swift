//
//  ListSnapshot.swift
//  
//
//  Created by Ilya Kuznetsov on 21/09/2023.
//

#if os(iOS)
import UIKit
import SwiftUI

public final class ListSnapshot: Snapshot {
    public typealias S = Section<UITableViewCell, CellAdditions>
    
    public struct CellAdditions {
        enum Height {
            case automatic(estimated: (AnyHashable)->CGFloat = { _ in 150 })
            case fixed((AnyHashable)->CGFloat)
        }
        
        let height: Height
        var sideActions: ((AnyHashable)->[UIContextualAction])? = nil
    }
    
    public let data = SectionsContainer<S>()
    
    public var viewContainerInfo: S {
        S(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId }, additions: .init(height: .automatic()))
    }
    
    public func addSection<T: Hashable>(_ items: [T], section: S) {
        data.addNewSection(items, section: section)
    }
    
    public func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                                                  fill: @escaping (Item)-> Content,
                                                                  sideActions: ((Item)->[UIContextualAction])? = nil,
                                                                  estimatedHeight: @escaping (Item)->CGFloat = { _ in 150 }) {
        addSection(items, fill: fill,
                   additions: .init(height: .automatic(estimated: { estimatedHeight($0 as! Item) }),
                                    sideActions: sideActions == nil ? nil : { sideActions!($0 as! Item) }))
    }
    
    public func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                                                  fill: @escaping (Item)-> Content,
                                                                  sideActions: ((Item)->[UIContextualAction])? = nil,
                                                                  height: @escaping (Item)->CGFloat) {
        addSection(items, fill: fill,
                   additions: .init(height: .fixed({ height($0 as! Item) }),
                                    sideActions: sideActions == nil ? nil : { sideActions!($0 as! Item) }))
    }
    
    public func add<T: View>(_ view: T, staticHeight: CGFloat) {
        addSection([view.inContainer()], section: .init(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId }, additions: .init(height: .fixed({ _ in staticHeight }))))
    }
    
    private func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                                           fill: @escaping (Item)-> Content,
                                                           additions: CellAdditions) {
        let reuseId = String(describing: Item.self)
        
        addSection(items, section: .init(Item.self, fill: { item, cell in
            if #available(iOS 16, *) {
                cell.contentConfiguration = UIHostingConfiguration { fill(item) }.margins(.all, 0)
            } else {
                cell.contentConfiguration = UIHostingConfigurationBackport { fill(item).ignoresSafeArea() }.margins(.all, 0)
            }
        }, reuseId: { _ in reuseId }, additions: additions))
    }
}
#endif
