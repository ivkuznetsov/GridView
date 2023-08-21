//
//  CollectionView.swift
//

#if os(iOS)
import UIKit

public typealias PlatformCollectionLayout = UICollectionViewCompositionalLayout
public typealias PlatformCollectionView = UICollectionView
public typealias PlatformCollectionCell = UICollectionViewCell
#else
import AppKit

public typealias PlatformCollectionLayout = NSCollectionViewCompositionalLayout
public typealias PlatformCollectionView = NSCollectionView
public typealias PlatformCollectionCell = NSCollectionViewItem
#endif

final class CollectionViewLayout: PlatformCollectionLayout {
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size ?? newBounds.size != newBounds.size
    }
}

public final class CollectionView: PlatformCollectionView {
    
    public var attachedContentToTheBottom: Bool = false
    
    #if os(iOS)
    public required override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        canCancelContentTouches = true
        delaysContentTouches = false
        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .automatic
        showsHorizontalScrollIndicator = false
    }
    
    public override var bounds: CGRect {
        didSet {
            if bounds.height != oldValue.height, attachedContentToTheBottom {
                let offset = oldValue.height - frame.height
                
                if offset > 0 {
                    var contentOffset = self.contentOffset
                    contentOffset.y += offset
                    contentOffset.y = min(contentOffset.y, max(0, contentSize.height - bounds.size.height))
                    self.contentOffset = contentOffset
                }
            }
        }
    }
    
    public override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIControl ? true : super.touchesShouldCancel(in: view)
    }
    
    #else
    public override var acceptsFirstResponder: Bool { false }
    #endif
}

public extension PlatformCollectionView {
    
    static var cellsKey = "cellsKey"
    
    #if os(iOS)
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #else
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #endif
    
    func createCell(reuseId: String, at indexPath: IndexPath) -> PlatformCollectionCell {
        
        if !registeredCells.contains(reuseId) {
            #if os(iOS)
            register(PlatformCollectionCell.self, forCellWithReuseIdentifier: reuseId)
            #else
            register(PlatformCollectionCell.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: reuseId))
            #endif
            registeredCells.insert(reuseId)
        }
        #if os(iOS)
        return dequeueReusableCell(withReuseIdentifier: reuseId, for: indexPath)
        #else
        return makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: reuseId), for: indexPath)
        #endif
    }
    
    func enumerateVisibleCells(_ action: (IndexPath, PlatformCollectionCell)->()) {
        #if os(iOS)
        let visibleCells = visibleCells
        #else
        let visibleCells = visibleItems()
        #endif
        visibleCells.forEach { cell in
            if let indexPath = indexPath(for: cell) {
                action(indexPath, cell)
            }
        }
    }
}
