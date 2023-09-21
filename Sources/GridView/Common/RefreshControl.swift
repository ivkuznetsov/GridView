//
//  RefreshControl.swift
//

#if os(iOS)
import Foundation
import UIKit

final class RefreshControl: UIRefreshControl {
    
    private let action: ()->()
    
    init(_ action: @escaping () -> Void) {
        self.action = action
        super.init()
        addTarget(self, action: #selector(refreshAction), for: .valueChanged)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if window != nil && isRefreshing, let scrollView = superview as? UIScrollView {
            let offset = scrollView.contentOffset
            UIView.performWithoutAnimation { endRefreshing() }
            beginRefreshing()
            scrollView.contentOffset = offset
        }
    }
    
    @objc func refreshAction() {
        action()
    }
}
#endif
