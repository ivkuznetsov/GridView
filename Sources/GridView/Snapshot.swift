//
//  Snapshot.swift
//  

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

public struct PrefetchCancel {
    let cancel: ()->()

    public init(_ cancel: @escaping ()->()) {
        self.cancel = cancel
    }
}

public struct Snapshot {
    public typealias Layout = (NSCollectionLayoutEnvironment)->NSCollectionLayoutSection
    
    final class Section {
        
        let fill: (AnyHashable, PlatformCollectionCell)->()
        let typeCheck: (AnyHashable)->Bool
        let reuseId: (AnyHashable)->String
        let prefetch: ((AnyHashable)->PrefetchCancel?)?
        let layout: Layout
        
        init<Item: Hashable>(_ item: Item.Type,
                             fill: @escaping (Item, PlatformCollectionCell)->(),
                             reuseId: @escaping (Item)->String,
                             prefetch: ((Item)->PrefetchCancel)? = nil,
                             layout: @escaping Layout) {
            
            self.fill = { fill($0 as! Item, $1) }
            self.typeCheck = { $0 is Item }
            self.reuseId = { reuseId($0 as! Item) }
            self.prefetch = prefetch == nil ? nil : { prefetch!($0 as! Item) }
            self.layout = layout
        }
    }
    
    private(set) var sections: [Section] = []
    public private(set) var data = NSDiffableDataSourceSnapshot<String, AnyHashable>()
    private var sectionIds = Set<String>()
    
    public init() {}
    
    private var viewContainerInfo: Section {
        Section(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId }, layout: { .grid($0) })
    }
    
    public mutating func add<T: View>(_ view: T) {
        addSection([view.inContainer()])
    }
    
    public mutating func add(_ view: ViewContainer) {
        addSection([view])
    }
    
    public mutating func addSection(_ views: [ViewContainer]) {
        addSection(views, section: viewContainerInfo)
    }
    
    mutating func add(_ item: AnyHashable, sectionId: String) {
        data.appendItems([item], toSection: sectionId)
    }
    
    mutating func addSection<T: Hashable>(_ items: [T], section: Section) {
        let className = String(describing: T.self)
        var sectionId = className
        var counter = 0
        while sectionIds.contains(sectionId) {
            counter += 1
            sectionId = className + "\(counter)"
        }
        sectionIds.insert(sectionId)
        data.appendSections([sectionId])
        data.appendItems(items, toSection: sectionId)
        sections.append(section)
    }
    
    func info(_ indexPath: IndexPath) -> (section: Section, item: AnyHashable)? {
        if let section = sections[safe: indexPath.section],
           let sectionId = data.sectionIdentifiers[safe: indexPath.section],
           let item = data.itemIdentifiers(inSection: sectionId)[safe: indexPath.item] {
            return (section, item)
        }
        return nil
    }
    
    public mutating func addViewSectionId(_ id: String) {
        data.appendSections([id])
        sections.append(viewContainerInfo)
    }
    
    public mutating func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                             fill: @escaping (Item)-> Content,
                                             prefetch: ((Item)->PrefetchCancel)? = nil,
                                             layout: @escaping Layout = { .grid($0) }) {
        let reuseId = String(describing: Item.self)
        
        addSection(items, section: .init(Item.self, fill: { item, cell in
            if #available(iOS 16, *) {
                cell.contentConfiguration = UIHostingConfiguration { fill(item) }.margins(.all, 0)
            } else {
                cell.contentConfiguration = UIHostingConfigurationBackport { fill(item).ignoresSafeArea() }.margins(.all, 0)
            }
        }, reuseId: { _ in reuseId }, layout: layout))
    }
    
    public mutating func add<T: View>(_ view: T, staticHeight: CGFloat) {
        addSection([view.inContainer()], section: .init(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId }, layout: {
            .grid(height: staticHeight, estimatedHeight: staticHeight, $0)
        }))
    }
}
