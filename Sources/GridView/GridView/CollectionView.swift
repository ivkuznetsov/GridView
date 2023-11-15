//
//  CollectionView.swift
//

#if os(iOS)
import UIKit

public typealias PlatformLayout = UICollectionViewLayout
public typealias PlatformCollectionCompositionLayout = UICollectionViewCompositionalLayout
public typealias PlatformCollectionLayout = UICollectionViewFlowLayout
public typealias PlatformCollectionView = UICollectionView
public typealias PlatformCollectionCell = UICollectionViewCell
#else
import AppKit

public typealias PlatformLayout = NSCollectionViewLayout
public typealias PlatformCollectionCompositionLayout = NSCollectionViewCompositionalLayout
public typealias PlatformCollectionLayout = NSCollectionViewFlowLayout
public typealias PlatformCollectionView = NSCollectionView
public typealias PlatformCollectionCell = NSCollectionViewItem
#endif

final class CollectionViewCompositionLayout: PlatformCollectionCompositionLayout {
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size ?? newBounds.size != newBounds.size
    }
}

final class CollectionViewFlowLayout: PlatformCollectionLayout {
    
    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        if let collectionView = collectionView, let context = context as? UICollectionViewFlowLayoutInvalidationContext {
            context.invalidateFlowLayoutDelegateMetrics = collectionView.bounds.size != newBounds.size
        }
        return context
    }
    
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
    
    struct UpdateTransaction {
        let animated: Bool
    }
    
    var transaction: UpdateTransaction?
    
    private func setup() {
        canCancelContentTouches = true
        delaysContentTouches = false
        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .always
        showsHorizontalScrollIndicator = false
    }
    
    public override var contentSize: CGSize {
        didSet {
            if attachedContentToTheBottom, transaction?.animated == false && oldValue.height != contentSize.height {
                let resultOffset = contentOffset.y + (contentSize.height - oldValue.height)
                let offset = CGPoint(x: contentOffset.x, y: max(0, min(resultOffset, contentSize.height - frame.size.height)))
                setContentOffset(offset, animated: false)
            }
        }
    }
    
    private func update(frame: CGRect, oldValue: CGRect) {
        if frame.height != oldValue.height, attachedContentToTheBottom {
            let offset = oldValue.height - frame.height
            
            if offset > 0 {
                var contentOffset = self.contentOffset
                contentOffset.y += offset
                contentOffset.y = min(contentOffset.y, max(0, contentSize.height - frame.size.height))
                self.contentOffset = contentOffset
            }
        }
    }
    
    public override var bounds: CGRect {
        didSet { update(frame: bounds, oldValue: oldValue) }
    }
    
    public override var frame: CGRect {
        didSet { update(frame: bounds, oldValue: oldValue) }
    }
    
    public override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIControl ? true : super.touchesShouldCancel(in: view)
    }
    
    #else
    public override var acceptsFirstResponder: Bool { false }
    #endif
}

public extension PlatformCollectionView {
    
    static var cellsKey = 0
    
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
