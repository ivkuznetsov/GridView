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
    public let dataSource: UITableViewDiffableDataSource<String, AnyHashable>
    
    public init() {
        let view = UITableView(frame: .zero)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        dataSource = .init(tableView: view, cellProvider: { [storage, view] in
            storage.cell(view: view, indexPath: $1, item: $2)
        })
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
        if let info = storage.snapshot.info(indexPath) {
            if let actions = info.section.additions.sideActions?(info.item) {
                let configuration = UISwipeActionsConfiguration(actions: actions)
                configuration.performsFirstActionWithFullSwipe = false
                return configuration
            }
        }
        return nil
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
