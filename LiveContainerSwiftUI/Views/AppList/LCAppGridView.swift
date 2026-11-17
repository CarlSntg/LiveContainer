//
//  LCAppGridView.swift
//  LiveContainerSwiftUI
//
//  Home screen style grid of app icons, rearranged by long-press and drag.
//

import SwiftUI
import UniformTypeIdentifiers

struct LCAppGridView: View {
    let apps: [LCAppModel]
    let delegate: LCAppBannerDelegate
    /// Show placeholder icons instead of the apps (locked hidden apps).
    var showSkeleton: Bool = false
    var onSkeletonTap: (() -> Void)? = nil

    @EnvironmentObject private var sortManager: LCAppSortManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // iPhone home screen: 60pt icons in 4 columns. iPad: 76pt icons, as many columns as fit.
    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 76 : 60
    }

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: iconSize + 44, maximum: iconSize + 64), spacing: 16)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    }

    private var cellHeight: CGFloat {
        LCAppIconRootView.cellHeight(iconSize: iconSize)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 26) {
            ForEach(apps, id: \.self) { app in
                if showSkeleton {
                    skeletonCell
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSkeletonTap?()
                        }
                } else {
                    LCAppBanner(appModel: app, delegate: delegate, style: .icon(size: iconSize))
                        .frame(maxWidth: .infinity)
                        .frame(height: cellHeight)
                        // Leave an empty slot where the dragged icon was, like the home screen.
                        .opacity(sortManager.draggingApp == app ? 0 : 1)
                        .onDrop(of: [UTType.plainText], delegate: LCAppGridDropDelegate(target: app, sortManager: sortManager))
                }
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 20)
        // Accept drops in the gaps between icons so the icon settles instead of flying back.
        .onDrop(of: [UTType.plainText], delegate: LCAppGridDropDelegate(target: nil, sortManager: sortManager))
    }

    private var skeletonCell: some View {
        VStack(spacing: LCAppIconRootView.labelSpacing) {
            RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous)
                .fill(Color.gray.opacity(0.3))
                .frame(width: iconSize, height: iconSize)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: iconSize * 0.8, height: 10)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight)
    }
}

/// Moves the dragged app into the slot of the icon it hovers over.
struct LCAppGridDropDelegate: DropDelegate {
    /// The app whose slot this delegate covers; nil for the grid background.
    let target: LCAppModel?
    let sortManager: LCAppSortManager

    func dropEntered(info: DropInfo) {
        guard let target,
              let draggingApp = sortManager.draggingApp,
              draggingApp != target else {
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            sortManager.moveApp(draggingApp, to: target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // The order is already saved while hovering; just end the drag.
        sortManager.draggingApp = nil
        return true
    }
}
