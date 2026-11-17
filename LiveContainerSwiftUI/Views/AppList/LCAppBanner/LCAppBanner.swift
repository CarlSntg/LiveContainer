//
//  LCAppBanner.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Foundation
import SwiftUI
import UIKit

protocol LCAppBannerDelegate {
    func removeApp(app: LCAppModel)
    func installMdm(data: Data)
    func openNavigationView(view: AnyView)
    func promptForGeneratedIconStyle() async -> GeneratedIconStyle?
}

enum LCAppBannerStyle: Equatable {
    /// Full-width banner with details and a Run button.
    case banner
    /// Home screen style: icon with the app name below it.
    case icon(size: CGFloat)

    var isIcon: Bool {
        if case .icon = self {
            return true
        }
        return false
    }
}

struct LCAppBanner: UIViewControllerRepresentable {
    var delegate: LCAppBannerDelegate
    var style: LCAppBannerStyle

    @ObservedObject var model: LCAppModel

    @AppStorage("dynamicColors", store: LCUtils.appGroupUserDefault) private var dynamicColors = true
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    private let sharedModel = DataManager.shared.model

    init(appModel: LCAppModel, delegate: LCAppBannerDelegate, style: LCAppBannerStyle = .banner) {
        _model = ObservedObject(wrappedValue: appModel)
        self.delegate = delegate
        self.style = style
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = LCAppBannerViewController(delegate: delegate, config: LCAppBannerConfiguration(model: model, dynamicColors: dynamicColors, darkModeIcon: darkModeIcon, style: style))
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let viewController = uiViewController as? LCAppBannerViewController else {
            return
        }
        viewController.update(
            model: model,
            dynamicColors: dynamicColors,
            darkModeIcon: darkModeIcon,
            style: style
        )
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIViewController, context: Context) -> CGSize? {
        switch style {
        case .banner:
            guard let width = proposal.width else {
                return nil
            }
            return CGSize(width: width, height: LCAppBannerRootView.bannerHeight)
        case .icon(let size):
            return CGSize(width: proposal.width ?? size, height: LCAppIconRootView.cellHeight(iconSize: size))
        }
    }
}
