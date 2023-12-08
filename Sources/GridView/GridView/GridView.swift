//
//  GridView.swift
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit

public typealias PlatformCollectionDelegate = UICollectionViewDelegateFlowLayout
public typealias PlatformCollectionDataSource = UICollectionViewDiffableDataSource<String, AnyHashable>

protocol PrefetchCollectionProtocol: UICollectionViewDataSourcePrefetching { }
#else
import AppKit

public typealias PlatformCollectionDelegate = NSCollectionViewDelegateFlowLayout
public typealias PlatformCollectionDataSource = NSCollectionViewDiffableDataSource<String, AnyHashable>

protocol PrefetchCollectionProtocol { }
#endif

public struct GridView: View, Equatable {
    
    public static func == (lhs: GridView, rhs: GridView) -> Bool {
        lhs.reuseId == rhs.reuseId
    }
    
    @StateObject private var state = GridState()
    
    private let reuseId: String
    private let parameters: Parameters<CollectionSnapshot, GridState>
    private let emptyState: EmptyState?
    
    public init(reuseId: String = UUID().uuidString,
                setup: ((GridState)->())? = nil,
                emptyState: EmptyState? = nil,
                animateChanges: Bool = true,
                snapshot: (CollectionSnapshot)->()) {
        let currentSnapshot = CollectionSnapshot()
        snapshot(currentSnapshot)
        parameters = .init(snapshot: currentSnapshot,
                           animateChanges: animateChanges,
                           setup: setup)
        self.reuseId = reuseId
        self.emptyState = emptyState
    }
    
    public var body: some View {
        ZStack {
            GridCollectionView(state: state, parameters: parameters)
            emptyState?.viewIfNeeded(parameters.snapshot.numberOfItems)
        }
    }
}

public final class GridState: BaseState<CollectionView>, PlatformCollectionDelegate, PrefetchCollectionProtocol {
    
    public final class DataSource: PlatformCollectionDataSource {
        
        private let storage: Storage
        
        public override func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
            storage.snapshot.info(indexPath)?.section.move != nil
        }
        
        init(view: CollectionView, storage: Storage) {
            self.storage = storage
            super.init(collectionView: view, cellProvider: { [storage, view] in
                storage.cell(view: view, indexPath: $1, item: $2)
            })
        }
        
        public override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            var snapshot = self.snapshot()
            if let from = itemIdentifier(for: sourceIndexPath) {
                if let to = itemIdentifier(for: destinationIndexPath) {
                    guard from != to else { return }
                    
                    if sourceIndexPath.row > destinationIndexPath.row {
                        snapshot.moveItem(from, beforeItem: to)
                    } else {
                        snapshot.moveItem(from, afterItem: to)
                    }
                } else {
                    snapshot.deleteItems([from])
                    snapshot.appendItems([from], toSection: snapshot.sectionIdentifiers[destinationIndexPath.section])
                }
            }
            apply(snapshot, animatingDifferences: false, completion: {
                self.storage.snapshot.info(sourceIndexPath)?.section.move?.commit(sourceIndexPath, destinationIndexPath)
            })
        }
    }
    
    @MainActor
    public final class Storage {
        public internal(set) var oldSnapshot: CollectionSnapshot?
        public private(set) var snapshot = CollectionSnapshot()
        
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
        
        func update(_ snapshot: CollectionSnapshot) {
            oldSnapshot = self.snapshot
            self.snapshot = snapshot
        }
    }
    
    public let storage = Storage()
    public let dataSource: DataSource
    public var configureLayout: ((PlatformLayout)->())?
    
    public init() {
        #if os(iOS)
        let view = CollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
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
        
        dataSource = .init(view: view, storage: storage)
        super.init(view: view)
        
        #if os(iOS)
        reordering.minimumPressDuration = 0
        view.addGestureRecognizer(reordering)
        reordering.addTarget(self, action: #selector(handleLongGesture(gesture:)))
        reordering.isEnabled = false
        #endif
    }
    
    #if os(iOS)
    public let reordering = UILongPressGestureRecognizer()
    
    @objc private func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        switch(gesture.state) {
            
        case .began:
            if let indexPath = view.indexPathForItem(at: gesture.location(in: view)) {
                view.beginInteractiveMovementForItem(at: indexPath)
            }
        case .changed:
            view.updateInteractiveMovementTargetPosition(gesture.location(in: view))
        case .ended:
            view.endInteractiveMovement()
        default:
            view.cancelInteractiveMovement()
        }
    }
    #endif

    private func reloadLayout(_ snapshot: CollectionSnapshot) {
        switch snapshot.layout {
        case .perItem:
            if view.collectionViewLayout is CollectionViewFlowLayout { return }
            
            let layout = CollectionViewFlowLayout()
            layout.sectionInset = .zero
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            #if os(iOS)
            view.setCollectionViewLayout(layout, animated: false)
            #else
            view.collectionViewLayout = layout
            #endif
        case .autosizing:
            if view.collectionViewLayout is CollectionViewCompositionLayout { return }
            
            let layout = CollectionViewCompositionLayout { [storage] in
                if let layout = storage.snapshot.data.info[safe: $0]?.additions.layout {
                    switch layout {
                    case .autosizing(let layout): return layout($1)
                    case .perItem(_): fatalError("Per item size is not supported by autosizable layout")
                    }
                }
                return .grid($1)
            }
            #if os(iOS)
            view.setCollectionViewLayout(layout, animated: false)
            #else
            view.collectionViewLayout = layout
            #endif
        }
        configureLayout?(view.collectionViewLayout)
    }
    
    public func set(_ snapshot: CollectionSnapshot, animated: Bool = false) async {
        try? await updateSync.run { @MainActor in
            let resultAnimation = animated && self.storage.snapshot.numberOfItems > 0
            self.view.transaction = .init(animated: resultAnimation)
            self.storage.update(snapshot)
            self.reloadLayout(snapshot)
            
            await withCheckedContinuation { continuation in // async apply function is non isolated and posts main thread checker errors
                self.dataSource.apply(snapshot.data.snapshot, animatingDifferences: resultAnimation) {
                    continuation.resume()
                }
            }
            self.view.transaction = nil
            self.didSet?()
        }
    }
    
    public func item(_ indexPath: IndexPath) -> AnyHashable? {
        storage.snapshot.info(indexPath)?.item
    }
    
    #if os(iOS)
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let info = storage.snapshot.info(indexPath) {
            switch info.section.additions.layout {
            case .perItem(let layout):
                let contentWidth = collectionView.frame.size.width - collectionView.safeAreaInsets.left - collectionView.safeAreaInsets.right - collectionView.contentInset.left - collectionView.contentInset.right
                return layout(info.item, contentWidth)
            case .autosizing(_): fatalError("Autosizable layout is not supported by per item sizing")
            }
        }
        return .zero
    }
    
    private var prefetchTokens: [IndexPath:PrefetchCancel] = [:]
    
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        prefetch(indexPaths)
    }

    private func prefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            if let info = storage.snapshot.info($0),
               let cancel = info.section.additions.prefetch?(info.item) {
                prefetchTokens[$0] = cancel
            }
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        cancelPrefetch(indexPaths)
    }
    
    public func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        storage.snapshot.info(currentIndexPath)?.section.move?.proposedDestination(source: currentIndexPath,
                                                                                  proposed: proposedIndexPath,
                                                                                  numberOfItemsInSection: {
            dataSource.collectionView(collectionView, numberOfItemsInSection: $0)
        }) ?? proposedIndexPath
    }
    
    private func cancelPrefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            prefetchTokens[$0]?.cancel()
            prefetchTokens[$0] = nil
        }
    }
    
    deinit {
        prefetchTokens.values.forEach { $0.cancel() }
    }
    #endif
}

private struct GridCollectionView: UIViewRepresentable {
    
    @ObservedObject var state: GridState
    let parameters: Parameters<CollectionSnapshot, GridState>
    
    public func makeUIView(context: Context) -> CollectionView {
        parameters.setup?(state)
        return state.view
    }
    
    public func updateUIView(_ uiView: CollectionView, context: Context) {
        Task { @MainActor in
            await state.set(parameters.snapshot,
                            animated: !context.transaction.disablesAnimations && parameters.animateChanges)
        }
    }
}
