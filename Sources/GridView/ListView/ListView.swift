//
//  ListView.swift
//

#if os(iOS)
import Foundation
import SwiftUI
import UIKit

public struct ListView: View, Equatable {
    
    public static func == (lhs: ListView, rhs: ListView) -> Bool {
        lhs.reuseId == rhs.reuseId
    }
    
    @StateObject private var state = ListState()
    
    private let reuseId: String
    private let parameters: Parameters<ListSnapshot, ListState>
    private let emptyState: EmptyState?
    
    public init(reuseId: String = UUID().uuidString,
                setup: ((ListState)->())? = nil,
                emptyState: EmptyState? = nil,
                animateChanges: Bool = true,
                snapshot: (ListSnapshot)->()) {
        let currentSnapshot = ListSnapshot()
        snapshot(currentSnapshot)
        parameters = .init(snapshot: currentSnapshot,
                           animateChanges: animateChanges,
                           setup: setup)
        self.emptyState = emptyState
        self.reuseId = reuseId
    }
    
    public var body: some View {
        ZStack {
            ListTableView(state: state, parameters: parameters)
            emptyState?.viewIfNeeded(parameters.snapshot.numberOfItems)
        }
    }
}

public final class ListState: BaseState<UITableView>, UITableViewDelegate {
    
    public final class DataSource: UITableViewDiffableDataSource<String, AnyHashable> {
        
        private let storage: Storage
        
        init(view: UITableView, storage: Storage) {
            self.storage = storage
            super.init(tableView: view, cellProvider: { [storage, view] in
                storage.cell(view: view, indexPath: $1, item: $2)
            })
        }
        
        public override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
            storage.snapshot.info(indexPath)?.section.move != nil
        }
        
        public override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
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
        public internal(set) var oldSnapshot: ListSnapshot?
        public private(set) var snapshot = ListSnapshot()
        
        func cell(view: UITableView, indexPath: IndexPath, item: AnyHashable) -> UITableViewCell {
            var info = snapshot.info(indexPath)?.section
            
            if info?.typeCheck(item) != true {
                info = oldSnapshot?.info(indexPath)?.section
                
                if info?.typeCheck(item) != true {
                    fatalError("No info for the item")
                }
            }
            let cell = view.createCell(reuseId: info!.reuseId(item), at: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            if cell.selectedBackgroundView == nil {
                let view = UIView()
                view.backgroundColor = UIColor(white: 0.5, alpha: 0.15)
                cell.selectedBackgroundView = view
            }
            info!.fill(item, cell)
            return cell
        }
        
        func update(_ snapshot: ListSnapshot) {
            oldSnapshot = self.snapshot
            self.snapshot = snapshot
        }
    }
    
    public let storage = Storage()
    public let dataSource: DataSource
    
    public init() {
        let view = UITableView(frame: .zero)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        dataSource = .init(view: view, storage: storage)
        dataSource.defaultRowAnimation = .fade
        super.init(view: view)
    }
    
    public func set(_ snapshot: ListSnapshot, animated: Bool = false) async {
        try? await updateSync.run { @MainActor in
            let oldCount = self.storage.snapshot.numberOfItems
            self.storage.update(snapshot)
            if self.view.window == nil {
                await self.dataSource.applySnapshotUsingReloadData(snapshot.data.snapshot)
            } else {
                await self.dataSource.apply(snapshot.data.snapshot,
                                            animatingDifferences: oldCount > 0 && animated)
            }
            self.didSet?()
        }
    }
    
    public func item(_ indexPath: IndexPath) -> AnyHashable? {
        storage.snapshot.info(indexPath)?.item
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let info = storage.snapshot.info(indexPath) {
            switch info.section.additions.height {
            case .automatic(_):
                return -1
            case .fixed(let height):
                return height(info.item)
            }
        }
        return -1
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if let info = storage.snapshot.info(indexPath) {
            switch info.section.additions.height {
            case .automatic(let estimated):
                return estimated(info.item)
            case .fixed(let height):
                return height(info.item)
            }
        }
        return 0
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let info = storage.snapshot.info(indexPath),
           let actions = info.section.additions.sideActions?(info.item) {
            let configuration = UISwipeActionsConfiguration(actions: actions)
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        storage.snapshot.info(indexPath)?.section.additions.sideActions == nil ? .none : .delete
    }
    
    public func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { false }
    
    public func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        storage.snapshot.info(sourceIndexPath)?.section.move?.proposedDestination(source: sourceIndexPath,
                                                                                  proposed: proposedDestinationIndexPath,
                                                                                  numberOfItemsInSection: {
            dataSource.tableView(tableView, numberOfRowsInSection: $0)
        }) ?? proposedDestinationIndexPath
    }
}

private struct ListTableView: UIViewRepresentable {
    
    @ObservedObject var state: ListState
    let parameters: Parameters<ListSnapshot, ListState>
    
    public func makeUIView(context: Context) -> UITableView {
        parameters.setup?(state)
        return state.view
    }
    
    public func updateUIView(_ uiView: UITableView, context: Context) {
        Task { @MainActor in
            await state.set(parameters.snapshot,
                            animated: !context.transaction.disablesAnimations && parameters.animateChanges)
        }
    }
}
#endif
