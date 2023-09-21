//
//  BaseState.swift
//  
//
//  Created by Ilya Kuznetsov on 21/09/2023.
//

import Foundation

#if os(iOS)
import UIKit

public typealias PlatformScrollDelegate = UIScrollViewDelegate
#else
import AppKit

public typealias PlatformScrollDelegate = NSScrollViewDelegate
#endif

struct Parameters<S: Snapshot, State> {
    let snapshot: S
    let animateChanges: Bool
    let setup: ((State)->())?
}

@MainActor
public class BaseState<ScrollView: UIScrollView>: NSObject, PlatformScrollDelegate, ObservableObject {
    
    let updateSync = TaskSync()
    
    public let view: ScrollView
    private var performedEndRefreshing = false
    private var performedRefresh = false
    
    public var didScroll: ((_ offset: CGPoint)->())?
    public var didSet: (()->())?
    
    init(view: ScrollView) {
        self.view = view
        super.init()
        view.delegate = self
    }
    
    #if os(iOS)
    public var refresh: (() async -> ())? {
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
    }

    @objc public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { endDecelerating() }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll?(scrollView.contentOffset)
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
    #endif
}
