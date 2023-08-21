//
//  GridView.swift
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit

public typealias PlatformCollectionDelegate = UICollectionViewDelegate
public typealias PlatformCollectionDataSource = UICollectionViewDiffableDataSource<String, AnyHashable>

protocol PrefetchCollectionProtocol: UICollectionViewDataSourcePrefetching { }
#else
import AppKit

public typealias PlatformCollectionDelegate = NSCollectionViewDelegate
public typealias PlatformCollectionDataSource = NSCollectionViewDiffableDataSource<String, AnyHashable>

protocol PrefetchCollectionProtocol { }
#endif

public struct GridView: View {
    
    @StateObject private var state = GridState()
    
    fileprivate struct Parameters {
        let snapshot: Snapshot
        let refresh: (() async -> ())?
        let setup: ((GridState)->())?
        let didSet: (()->())?
    }
    
    private let parameters: Parameters
    private let emptyState: EmptyState?
    
    public init(setup: ((GridState)->())? = nil,
                didSet: (()->())? = nil,
                refresh: (() async -> ())? = nil,
                emptyState: EmptyState? = nil,
                snapshot: (inout Snapshot)->()) {
        var currentSnapshot = Snapshot()
        snapshot(&currentSnapshot)
        parameters = .init(snapshot: currentSnapshot,
                           refresh: refresh,
                           setup: setup,
                           didSet: didSet)
        self.emptyState = emptyState
    }
    
    public init<EmptyState: View>(setup: ((GridState)->())? = nil,
                didSet: (()->())? = nil,
                refresh: (() async -> ())? = nil,
                emptyState: EmptyState,
                snapshot: (inout Snapshot)->()) {
        self.init(setup: setup,
                  didSet: didSet,
                  refresh: refresh,
                  emptyState: .init({ emptyState }),
                  snapshot: snapshot)
    }
    
    public var body: some View {
        ZStack {
            GridCollectionView(state: state, parameters: parameters)
            if let emptyState = emptyState,
                emptyState.isPresented?() == true || (emptyState.isPresented == nil && parameters.snapshot.data.numberOfItems == 0) {
                emptyState.view
            }
        }
    }
}

@MainActor
public final class GridState: NSObject, PlatformCollectionDelegate, PrefetchCollectionProtocol, ObservableObject {
    
    private actor TaskSync {
        
        private var task: Task<Any, Error>?
        
        public func run<Success>(_ block: @Sendable @escaping () async throws -> Success) async throws -> Success {
            task = Task { [task] in
                _ = await task?.result
                return try await block() as Any
            }
            return try await task!.value as! Success
        }
    }
    
    @MainActor
    public final class Storage {
        var oldSnapshot: Snapshot?
        public private(set) var snapshot = Snapshot()
        
        func cell(view: CollectionView, indexPath: IndexPath, item: AnyHashable) -> UICollectionViewCell {
            var info = snapshot.info(indexPath)?.section
            
            if info?.typeCheck(item) != true {
                info = oldSnapshot?.info(indexPath)?.section
                
                if info?.typeCheck(item) != true {
                    fatalError("No info for the item")
                }
            }
            
            let cell = view.createCell(reuseId: info!.reuseId(item), at: indexPath)
            info!.fill(item, cell)
            return cell
        }
        
        func update(_ snapshot: Snapshot) {
            oldSnapshot = self.snapshot
            self.snapshot = snapshot
        }
    }
    
    private let updateSync = TaskSync()
    
    public let view: CollectionView
    public let delegate = DelegateForwarder()
    public let storage = Storage()
    public let dataSource: PlatformCollectionDataSource
    
    override init() {
        #if os(iOS)
        view = CollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        #else
        let scrollView = NSScrollView()
        view = CollectionView(frame: .zero)
        view.isSelectable = true
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.canDrawConcurrently = true
        scrollView.documentView = collection
        scrollView.drawsBackground = true
        view.backgroundColors = [.clear]
        #endif
        
        dataSource = PlatformCollectionDataSource(collectionView: view) { [storage, view] in
            storage.cell(view: view, indexPath: $1, item: $2)
        }
        super.init()
        
        let layout = CollectionViewLayout { [storage] in
            storage.snapshot.sections[safe: $0]?.layout($1) ?? .grid($1)
        }
        #if os(iOS)
        view.setCollectionViewLayout(layout, animated: false)
        #else
        view.collectionViewLayout = layout
        #endif
        
        delegate.addConforming(PlatformCollectionDelegate.self)
        delegate.add(self)
        view.delegate = delegate as? PlatformCollectionDelegate
    }
    
    public func set(_ snapshot: Snapshot, animated: Bool = false) async {
        try? await updateSync.run {
            await self.storage.update(snapshot)
            await self.dataSource.apply(snapshot.data, animatingDifferences: animated)
        }
    }
    
    public func item(_ indexPath: IndexPath) -> AnyHashable? {
        let snapshot = dataSource.snapshot()
        if let section = snapshot.sectionIdentifiers[safe: indexPath.section] {
            return snapshot.itemIdentifiers(inSection: section)[safe: indexPath.item]
        }
        return nil
    }
    
    #if os(iOS)
    private var prefetchTokens: [IndexPath:PrefetchCancel] = [:]
    
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        prefetch(indexPaths)
    }

    public func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        cancelPrefetch(indexPaths)
    }
    
    private func prefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            if let info = storage.snapshot.info($0),
               let cancel = info.section.prefetch?(info.item) {
                prefetchTokens[$0] = cancel
            }
        }
    }

    private func cancelPrefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            prefetchTokens[$0]?.cancel()
            prefetchTokens[$0] = nil
        }
    }

    private var performedEndRefreshing = false
    private var performedRefresh = false
    
    fileprivate var refresh: (() async -> ())? {
        didSet {
            if oldValue == nil, refresh != nil {
                view.refreshControl = RefreshControl({ [weak self] in
                    self?.performedRefresh = true
                })
            } else if refresh == nil {
                view.refreshControl = nil
            }
        }
    }
    
    @objc public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        endDecelerating()
        delegate.without(self) {
            (delegate as? UIScrollViewDelegate)?.scrollViewDidEndDecelerating?(scrollView)
        }
    }

    @objc public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { endDecelerating() }
        delegate.without(self) {
            (delegate as? UIScrollViewDelegate)?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }
    }

    func endDecelerating() {
        if performedEndRefreshing && !view.isDecelerating && !view.isDragging {
            performedEndRefreshing = false
            DispatchQueue.main.async { [weak view] in
                view?.refreshControl?.endRefreshing()
            }
        }
        if performedRefresh {
            performedRefresh = false
            Task { @MainActor in
                await refresh?()
                endRefreshing()
            }
        }
    }

    private func endRefreshing() {
        guard let refreshControl = view.refreshControl else { return }
        
        if view.isDecelerating || view.isDragging {
            performedEndRefreshing = true
        } else if view.window != nil && refreshControl.isRefreshing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                refreshControl.endRefreshing()
            })
        } else {
            refreshControl.endRefreshing()
        }
    }
    
    deinit {
        prefetchTokens.values.forEach { $0.cancel() }
    }
    #endif
}

public struct EmptyState {
    let view: AnyView
    let isPresented: (()->Bool)?
    
    public init<EmptyView: View>(_ view: ()->EmptyView, isPresented: (()->Bool)? = nil) {
        self.view = AnyView(view())
        self.isPresented = isPresented
    }
}

private struct GridCollectionView: UIViewRepresentable {
    
    @ObservedObject var state: GridState
    let parameters: GridView.Parameters
    
    public func makeUIView(context: Context) -> CollectionView {
        parameters.setup?(state)
        return state.view
    }
    
    public func updateUIView(_ uiView: CollectionView, context: Context) {
        state.refresh = parameters.refresh
        Task { @MainActor in
            let animated = !context.transaction.disablesAnimations && (state.storage.oldSnapshot?.data.numberOfItems ?? 0) > 0
            await state.set(parameters.snapshot, animated: animated)
            parameters.didSet?()
        }
    }
}

extension Collection where Indices.Iterator.Element == Index {
    
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
}
