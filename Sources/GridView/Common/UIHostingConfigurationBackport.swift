//
//  UIHostingConfigurationBackport.swift
//  

#if os(iOS)
import UIKit
import SwiftUI

struct UIHostingConfigurationBackport<Content, Background>: UIContentConfiguration where Content: View, Background: View {
    let content: Content
    let background: Background
    let margins: NSDirectionalEdgeInsets
    let minWidth: CGFloat?
    let minHeight: CGFloat?

    init(@ViewBuilder content: () -> Content) where Background == EmptyView {
        self.content = content()
        background = .init()
        margins = .zero
        minWidth = nil
        minHeight = nil
    }

    init(content: Content,
         background: Background,
         margins: NSDirectionalEdgeInsets,
         minWidth: CGFloat?,
         minHeight: CGFloat?) {
        self.content = content
        self.background = background
        self.margins = margins
        self.minWidth = minWidth
        self.minHeight = minHeight
    }
    
    func makeContentView() -> UIView & UIContentView {
        return UIHostingContentViewBackport<Content, Background>(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> UIHostingConfigurationBackport {
        return self
    }

    func background<S>(_ style: S) -> UIHostingConfigurationBackport<Content, _UIHostingConfigurationBackgroundViewBackport<S>> where S: ShapeStyle {
        return UIHostingConfigurationBackport<Content, _UIHostingConfigurationBackgroundViewBackport<S>>(
            content: content,
            background: .init(style: style),
            margins: margins,
            minWidth: minWidth,
            minHeight: minHeight
        )
    }

    func background<B>(@ViewBuilder content: () -> B) -> UIHostingConfigurationBackport<Content, B> where B: View {
        return UIHostingConfigurationBackport<Content, B>(
            content: self.content,
            background: content(),
            margins: margins,
            minWidth: minWidth,
            minHeight: minHeight
        )
    }

    func margins(_ insets: EdgeInsets) -> UIHostingConfigurationBackport<Content, Background> {
        return UIHostingConfigurationBackport<Content, Background>(
            content: content,
            background: background,
            margins: .init(insets),
            minWidth: minWidth,
            minHeight: minHeight
        )
    }

    func margins(_ edges: Edge.Set = .all, _ length: CGFloat) -> UIHostingConfigurationBackport<Content, Background> {
        return UIHostingConfigurationBackport<Content, Background>(
            content: content,
            background: background,
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

    func minSize(width: CGFloat? = nil, height: CGFloat? = nil) -> UIHostingConfigurationBackport<Content, Background> {
        return UIHostingConfigurationBackport<Content, Background>(
            content: content,
            background: background,
            margins: margins,
            minWidth: width,
            minHeight: height
        )
    }
}

final class UIHostingContentViewBackport<Content, Background>: UIView, UIContentView where Content: View, Background: View {
    typealias HostingController = UIHostingController<ZStack<TupleView<(Background, Content)>>?>
    
    private let hostingController: HostingController = {
        let controller = HostingController(rootView: nil, ignoreSafeArea: true)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        return controller
    }()

    var configuration: UIContentConfiguration {
        didSet {
            if let configuration = configuration as? UIHostingConfigurationBackport<Content, Background> {
                hostingController.rootView = ZStack {
                    configuration.background
                    configuration.content
                }
                directionalLayoutMargins = configuration.margins
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        var intrinsicContentSize = super.intrinsicContentSize
        if let configuration = configuration as? UIHostingConfigurationBackport<Content, Background> {
            if let width = configuration.minWidth {
                intrinsicContentSize.width = max(intrinsicContentSize.width, width)
            }
            if let height = configuration.minHeight {
                intrinsicContentSize.height = max(intrinsicContentSize.height, height)
            }
        }
        return intrinsicContentSize
    }

    init(configuration: UIContentConfiguration) {
        self.configuration = configuration

        super.init(frame: .zero)
    
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      
        leadingAnchor.constraint(equalTo: hostingController.view.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: hostingController.view.topAnchor).isActive = true
        let constraint = bottomAnchor.constraint(equalTo: hostingController.view.bottomAnchor)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        addSubview(hostingController.view)
        layoutMargins = .zero
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

struct _UIHostingConfigurationBackgroundViewBackport<S>: View where S: ShapeStyle {
    let style: S

    var body: some View {
        Rectangle().fill(style)
    }
}

private extension UIResponder {
    var parentViewController: UIViewController? {
        return next as? UIViewController ?? next?.parentViewController
    }
}
#endif
