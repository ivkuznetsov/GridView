//
//  UIHostingConfigurationBackport.swift
//  

#if os(iOS)
import UIKit
import SwiftUI
import Combine

struct UIHostingConfigurationBackport<Content>: UIContentConfiguration where Content: View {
    let content: Content
    let margins: NSDirectionalEdgeInsets
    let minWidth: CGFloat?
    let minHeight: CGFloat?
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        margins = .zero
        minWidth = nil
        minHeight = nil
    }

    init(content: Content,
         margins: NSDirectionalEdgeInsets,
         minWidth: CGFloat?,
         minHeight: CGFloat?) {
        self.content = content
        self.margins = margins
        self.minWidth = minWidth
        self.minHeight = minHeight
    }
    
    func makeContentView() -> UIView & UIContentView { UIHostingContentViewBackport<Content>(configuration: self) }

    func updated(for state: UIConfigurationState) -> UIHostingConfigurationBackport { self }

    func margins(_ insets: EdgeInsets) -> UIHostingConfigurationBackport<Content> {
        return UIHostingConfigurationBackport<Content>(
            content: content,
            margins: .init(insets),
            minWidth: minWidth,
            minHeight: minHeight
        )
    }

    func margins(_ edges: Edge.Set = .all, _ length: CGFloat) -> UIHostingConfigurationBackport<Content> {
        UIHostingConfigurationBackport<Content>(
            content: content,
            margins: .init(
                top: edges.contains(.top) ? length : margins.top,
                leading: edges.contains(.leading) ? length : margins.leading,
                bottom: edges.contains(.bottom) ? length : margins.bottom,
                trailing: edges.contains(.trailing) ? length : margins.trailing
            ),
            minWidth: minWidth,
            minHeight: minHeight
        )
    }

    func minSize(width: CGFloat? = nil, height: CGFloat? = nil) -> UIHostingConfigurationBackport<Content> {
        UIHostingConfigurationBackport<Content>(
            content: content,
            margins: margins,
            minWidth: width,
            minHeight: height
        )
    }
}

final class SizeObserver: ObservableObject {
    @Published var size: CGSize?
}

struct HostingContent<Content: View>: View {
    
    let sizeObserver: SizeObserver
    let content: Content
    
    var body: some View {
        content.background(
            GeometryReader { [weak sizeObserver] geometry in
                Color.clear
                    .onAppear {
                        if sizeObserver?.size != geometry.size {
                            sizeObserver?.size = geometry.size
                        }
                    }
                    .onChange(of: geometry.size) { newSize in
                        if sizeObserver?.size != newSize {
                            sizeObserver?.size = newSize
                        }
                    }
            }
        )
    }
}

final class UIHostingContentViewBackport<Content>: UIView, UIContentView where Content: View {
    typealias HostingController = UIHostingController<HostingContent<Content>?>
    
    private let hostingController: HostingController = {
        let controller = HostingController(rootView: nil, ignoreSafeArea: true)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        return controller
    }()

    private let sizeObserver = SizeObserver()
    
    var configuration: UIContentConfiguration {
        didSet {
            if let configuration = configuration as? UIHostingConfigurationBackport<Content> {
                hostingController.rootView = HostingContent(sizeObserver: sizeObserver, content: configuration.content)
                directionalLayoutMargins = configuration.margins
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        if let size = sizeObserver.size {
            print(size)
            
            return size
        }
        
        var intrinsicContentSize = super.intrinsicContentSize
        if let configuration = configuration as? UIHostingConfigurationBackport<Content> {
            if let width = configuration.minWidth {
                intrinsicContentSize.width = max(intrinsicContentSize.width, width)
            }
            if let height = configuration.minHeight {
                intrinsicContentSize.height = max(intrinsicContentSize.height, height)
            }
        }
        return intrinsicContentSize
    }

    private var observer: AnyCancellable?
    
    init(configuration: UIContentConfiguration) {
        self.configuration = configuration

        super.init(frame: .zero)
    
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      
        addSubview(hostingController.view)
        leadingAnchor.constraint(equalTo: hostingController.view.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: hostingController.view.topAnchor).isActive = true
        let constraint = bottomAnchor.constraint(equalTo: hostingController.view.bottomAnchor)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        layoutMargins = .zero
        
        observer = sizeObserver.$size.sink { [weak self] _ in
            if let cell = self?.hostingController.view.superview?.superview as? UICollectionViewCell {
                self?.hostingController.view.invalidateIntrinsicContentSize()
                cell.invalidateIntrinsicContentSize()
            } else if let cell = self?.hostingController.view.superview?.superview as? UITableViewCell {
                self?.hostingController.view.invalidateIntrinsicContentSize()
                cell.invalidateIntrinsicContentSize()
            }
        }
    }
   
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        if superview == nil {
            hostingController.willMove(toParent: nil)
            hostingController.removeFromParent()
        } else {
            parentViewController?.addChild(hostingController)
            hostingController.didMove(toParent: parentViewController)
        }
    }
}

private extension UIResponder {
    var parentViewController: UIViewController? {
        return next as? UIViewController ?? next?.parentViewController
    }
}
#endif
