//
//  Snapshot.swift
//  

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

public struct Move {

    public enum Destination {
        case perSection
        case custom((_ from: IndexPath, _ proposed: IndexPath)->IndexPath)
    }
    
    let destination: Destination
    let commit: (_ from: IndexPath, _ to: IndexPath)->()
    
    public init(destination: Destination = .perSection,
                commit: @escaping (_ from: IndexPath, _ to: IndexPath) -> Void) {
        self.destination = destination
        self.commit = commit
    }
    
    public static func perSection<T: Hashable>(_ array: Binding<[T]>) -> Move {
        .init { from, to in
            var value = array.wrappedValue
            value.move(fromOffsets: .init(integer: from.row), toOffset: from.row < to.row ? (to.row + 1) : to.row)
            array.wrappedValue = value
        }
    }
    
    func proposedDestination(source: IndexPath, proposed: IndexPath, numberOfItemsInSection: (Int)->Int) -> IndexPath {
        switch destination {
        case .custom(let custom): return custom(source, proposed)
        case .perSection:
            if source.section != proposed.section {
                var row = 0
                if source.section < proposed.section {
                    row = numberOfItemsInSection(source.section) - 1
                }
                return IndexPath(row: row, section: source.section)
            }
            return proposed
        }
    }
}

public struct DataSourceItem: @unchecked Sendable, Hashable {
    public let base: AnyHashable
    
    init<T: Hashable>(_ base: T) {
        self.base = base
    }
}

public final class Section<Cell, Additions> {
    
    let fill: (AnyHashable, Cell)->()
    let typeCheck: (AnyHashable)->Bool
    let reuseId: (AnyHashable)->String
    let additions: Additions
    var move: Move? = nil
    
    init<Item: Hashable>(_ item: Item.Type,
                         fill: @escaping (Item, Cell)->(),
                         reuseId: @escaping (Item)->String,
                         additions: Additions,
                         move: Move? = nil) {
        
        self.fill = { fill($0 as! Item, $1) }
        self.typeCheck = { $0 is Item }
        self.reuseId = { reuseId($0 as! Item) }
        self.additions = additions
        self.move = move
    }
}

@MainActor
public final class SectionsContainer<Section> {
    var ids = Set<String>()
    var info: [Section] = []
    public var snapshot = NSDiffableDataSourceSnapshot<String, DataSourceItem>()
    
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
        snapshot.appendItems(items.map { DataSourceItem($0) }, toSection: sectionId)
    }
}

public struct PrefetchCancel {
    let cancel: ()->()

    public init(_ cancel: @escaping ()->()) {
        self.cancel = cancel
    }
}

@MainActor
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
            return (section, item.base)
        }
        return nil
    }
}
