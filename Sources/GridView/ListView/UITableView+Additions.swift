//
//  UITableView.swift
//

#if os(iOS)
import UIKit

public extension UITableView {
    
    static var cellsKey = "cellsKey"
    
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &UITableView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &UITableView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    func createCell(reuseId: String, at indexPath: IndexPath) -> UITableViewCell {
        if !registeredCells.contains(reuseId) {
            register(UITableViewCell.self, forCellReuseIdentifier: reuseId)
            registeredCells.insert(reuseId)
        }
        return dequeueReusableCell(withIdentifier: reuseId, for: indexPath)
    }
}
#endif
