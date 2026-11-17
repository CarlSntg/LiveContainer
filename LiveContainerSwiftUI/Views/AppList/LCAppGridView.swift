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

    // iPhone values measured from a 402pt-wide home screen: 64pt icons, 4 columns on a
    // 92.6pt pitch (first icon 30.6pt from the edge), rows on a ~100pt pitch.
    // iPad: 76pt icons, as many columns as fit.
    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 76 : 64
    }

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: iconSize + 44, maximum: iconSize + 64), spacing: 16)]
        }
        // No gutter: each column is a full pitch wide and the icon sits centered in it.
        return Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }

    private var rowSpacing: CGFloat {
        // Row pitch of ~100.2pt minus the cell height (icon + gap + label line).
        horizontalSizeClass == .regular ? 26 : max(100.2 - cellHeight, 0)
    }

    private var cellHeight: CGFloat {
        LCAppIconRootView.cellHeight(iconSize: iconSize)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: rowSpacing) {
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
        .padding(.horizontal, horizontalPadding)
    }

    private var skeletonCell: some View {
        VStack(spacing: LCAppIconRootView.labelSpacing) {
            RoundedRectangle(cornerRadius: iconSize * LCAppIconRootView.cornerRadiusRatio, style: .continuous)
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
///
/// The drop itself is never accepted: the order is saved while hovering, and a cancelled drag
/// makes UIKit fly the icon back to its source view, which by then sits in the new slot.
/// That gives the home screen "settle into place" animation instead of the icon vanishing.
struct LCAppGridDropDelegate: DropDelegate {
    let target: LCAppModel
    let sortManager: LCAppSortManager

    func dropEntered(info: DropInfo) {
        guard let draggingApp = sortManager.draggingApp,
              draggingApp != target else {
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            sortManager.moveApp(draggingApp, to: target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        false
    }
}
