//
//  Snapshot.swift
//  

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

public final class Section<Cell, Additions> {
    
    let fill: (AnyHashable, Cell)->()
    let typeCheck: (AnyHashable)->Bool
    let reuseId: (AnyHashable)->String
    let additions: Additions
    
    init<Item: Hashable>(_ item: Item.Type,
                         fill: @escaping (Item, Cell)->(),
                         reuseId: @escaping (Item)->String,
                         additions: Additions) {
        
        self.fill = { fill($0 as! Item, $1) }
        self.typeCheck = { $0 is Item }
        self.reuseId = { reuseId($0 as! Item) }
        self.additions = additions
    }
}

public final class SectionsContainer<Section> {
    var ids = Set<String>()
    var info: [Section] = []
    public var snapshot = NSDiffableDataSourceSnapshot<String, AnyHashable>()
    
    func addNewSection<T: Hashable>(_ items: [T], section: Section) {
        let className = String(describing: T.self)
        var sectionId = className
        var counter = 0
        while ids.contains(sectionId) {
            counter += 1
            sectionId = className + "\(counter)"
        }
        ids.insert(sectionId)
        info.append(section)
        snapshot.appendSections([sectionId])
        snapshot.appendItems(items, toSection: sectionId)
    }
}

public struct PrefetchCancel {
    let cancel: ()->()

    public init(_ cancel: @escaping ()->()) {
        self.cancel = cancel
    }
}

public protocol Snapshot {
    associatedtype Section
    
    var data: SectionsContainer<Section> { get }
    
    var viewContainerInfo: Section { get }
    
    func addSection<T: Hashable>(_ items: [T], section: Section)
    
    func info(_ indexPath: IndexPath) -> (section: Section, item: AnyHashable)?
}

public extension Snapshot {
    
    var numberOfItems: Int { data.snapshot.numberOfItems }
    
    func add<T: View>(_ view: T) {
        addSection([view.inContainer()])
    }
    
    func add(_ view: ViewContainer) {
        addSection([view])
    }
    
    func addSection(_ views: [ViewContainer]) {
        addSection(views, section: viewContainerInfo)
    }
    
    func info(_ indexPath: IndexPath) -> (section: Section, item: AnyHashable)? {
        if let section = data.info[safe: indexPath.section],
           let sectionId = data.snapshot.sectionIdentifiers[safe: indexPath.section],
           let item = data.snapshot.itemIdentifiers(inSection: sectionId)[safe: indexPath.item] {
            return (section, item)
        }
        return nil
    }
}
