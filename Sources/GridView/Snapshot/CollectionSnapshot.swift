//
//  CollectionSnapshot.swift
//  
//
//  Created by Ilya Kuznetsov on 21/09/2023.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

public final class CollectionSnapshot: Snapshot {
    public typealias S = Section<PlatformCollectionCell, CellAdditions>
    
    public struct CellAdditions {
        enum Layout {
            enum Behaviour {
                case autosizing
                case perItem
            }
            
            case autosizing((NSCollectionLayoutEnvironment)->NSCollectionLayoutSection = { .grid($0) })
            case perItem((AnyHashable, CGFloat)->(CGSize))
            
            var behaviour: Behaviour {
                switch self {
                case .autosizing(_): return .autosizing
                case .perItem(_): return .perItem
                }
            }
        }
        
        let layout: Layout
        var prefetch: ((AnyHashable)->PrefetchCancel)? = nil
    }
    
    public let data = SectionsContainer<S>()
    
    private(set) var layout: CellAdditions.Layout.Behaviour = .autosizing
    
    public var viewContainerInfo: S {
        S(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId }, additions: .init(layout: .autosizing({ .grid($0) })))
    }
    
    public func addSection<T: Hashable>(_ items: [T], section: S) {
        if layout != section.additions.layout.behaviour {
            if data.info.isEmpty {
                layout = section.additions.layout.behaviour
            } else {
                fatalError("You cannot mix different layouts in one snapshot")
            }
        }
        data.addNewSection(items, section: section)
    }
    
    public func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                             fill: @escaping (Item)-> Content,
                                             prefetch: ((Item)->PrefetchCancel)? = nil,
                                             layout: @escaping (NSCollectionLayoutEnvironment)->NSCollectionLayoutSection = { .grid($0) }) {
        addSection(items, fill: fill, additions: .init(layout: .autosizing(layout),
                                                       prefetch: prefetch == nil ? nil : { prefetch!($0 as! Item) }))
    }
    
    public func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                             fill: @escaping (Item)-> Content,
                                             prefetch: ((Item)->PrefetchCancel)? = nil,
                                             itemSize: @escaping (Item, _ width: CGFloat)->CGSize) {
        addSection(items, fill: fill, additions: .init(layout: .perItem({ itemSize($0 as! Item, $1) }),
                                                       prefetch: prefetch == nil ? nil : { prefetch!($0 as! Item) }))
    }
    
    public func add<T: View>(_ view: T, staticHeight: CGFloat) {
        addSection([view.inContainer()], section: .init(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId }, additions: .init(layout: .autosizing({
            .grid(height: staticHeight, estimatedHeight: staticHeight, $0)
        }))))
    }
    
    public func add<T: View>(_ view: T, staticSize: @escaping (_ width: CGFloat)->CGSize) {
        addSection([view.inContainer()], section: .init(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId }, additions: .init(layout: .perItem({ _, width in staticSize(width) }))))
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
