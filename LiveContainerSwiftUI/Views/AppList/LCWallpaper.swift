//
//  LCWallpaper.swift
//  LiveContainerSwiftUI
//
//  Optional wallpaper behind the Home Screen layout: storage, rendering,
//  the photo picker, the pinch-and-drag adjust screen and the settings rows.
//

import SwiftUI
import PhotosUI

// MARK: - Settings keys

enum LCWallpaperKeys {
    static let scale = "LCHomeScreenWallpaperScale"
    static let offsetX = "LCHomeScreenWallpaperOffsetX"
    static let offsetY = "LCHomeScreenWallpaperOffsetY"
    static let dim = "LCHomeScreenWallpaperDim"

    static let maxScale: CGFloat = 5
    static let maxDim: Double = 0.6

    static func resetLayout() {
        let defaults = LCUtils.appGroupUserDefault
        defaults.removeObject(forKey: scale)
        defaults.removeObject(forKey: offsetX)
        defaults.removeObject(forKey: offsetY)
    }
}

// MARK: - Storage

/// Holds the wallpaper image. The file lives in this LiveContainer's Documents folder.
final class LCWallpaperStore: ObservableObject {
    static let shared = LCWallpaperStore()
    static let fileURL = LCPath.docPath.appendingPathComponent("HomeScreenWallpaper.jpg")
    /// Long side cap in pixels. Enough for any current screen at a little zoom, small enough to keep memory low.
    private static let maxPixelLength: CGFloat = 3000

    @Published private(set) var image: UIImage?

    private init() {
        image = UIImage(contentsOfFile: Self.fileURL.path)
    }

    /// Saves a new wallpaper and resets the zoom and position (the old ones belong to the old image).
    func setImage(_ newImage: UIImage) throws {
        let prepared = Self.prepared(newImage)
        guard let data = prepared.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "LCWallpaper", code: 1, userInfo: [NSLocalizedDescriptionKey: "lc.settings.homeScreen.wallpaperSaveError".loc])
        }
        try data.write(to: Self.fileURL, options: .atomic)
        LCWallpaperKeys.resetLayout()
        image = prepared
    }

    func remove() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        LCWallpaperKeys.resetLayout()
        image = nil
    }

    /// Downscales oversized photos and bakes in the orientation.
    private static func prepared(_ image: UIImage) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longSide = max(pixelSize.width, pixelSize.height)
        let factor = longSide > maxPixelLength ? maxPixelLength / longSide : 1
        let target = CGSize(width: floor(pixelSize.width * factor), height: floor(pixelSize.height * factor))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - Geometry

/// Where the image sits for a given container: aspect-fill, times the user's zoom,
/// moved by the user's offset (stored as a fraction of the container size), never showing an edge.
struct LCWallpaperGeometry {
    let imageSize: CGSize
    let container: CGSize

    private func fittedSize(scale: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let fill = max(container.width / imageSize.width, container.height / imageSize.height) * max(scale, 1)
        return CGSize(width: imageSize.width * fill, height: imageSize.height * fill)
    }

    private func maxOffset(scale: CGFloat) -> CGSize {
        let size = fittedSize(scale: scale)
        return CGSize(width: max((size.width - container.width) / 2, 0),
                      height: max((size.height - container.height) / 2, 0))
    }

    func size(scale: CGFloat) -> CGSize { fittedSize(scale: scale) }

    /// Offset in points, clamped so the image always covers the container.
    func offset(scale: CGFloat, normalized: CGSize) -> CGSize {
        let limit = maxOffset(scale: scale)
        return CGSize(width: min(max(normalized.width * container.width, -limit.width), limit.width),
                      height: min(max(normalized.height * container.height, -limit.height), limit.height))
    }

    /// The normalized offset after clamping, so a stored value never points past an edge.
    func clampedNormalized(scale: CGFloat, normalized: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0 else { return .zero }
        let points = offset(scale: scale, normalized: normalized)
        return CGSize(width: points.width / container.width, height: points.height / container.height)
    }
}

// MARK: - Rendering

struct LCWallpaperImageView: View {
    let image: UIImage
    let scale: CGFloat
    let offset: CGSize
    let dim: Double

    var body: some View {
        GeometryReader { geometry in
            let layout = LCWallpaperGeometry(imageSize: image.size, container: geometry.size)
            let size = layout.size(scale: scale)
            let point = layout.offset(scale: scale, normalized: offset)
            Image(uiImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)
                .offset(point)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(Color.black.opacity(dim))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The saved wallpaper with the saved zoom, position and dim. Draws nothing without a wallpaper.
struct LCWallpaperBackground: View {
    @ObservedObject private var store = LCWallpaperStore.shared
    @AppStorage(LCWallpaperKeys.scale, store: LCUtils.appGroupUserDefault) private var scale = 1.0
    @AppStorage(LCWallpaperKeys.offsetX, store: LCUtils.appGroupUserDefault) private var offsetX = 0.0
    @AppStorage(LCWallpaperKeys.offsetY, store: LCUtils.appGroupUserDefault) private var offsetY = 0.0
    @AppStorage(LCWallpaperKeys.dim, store: LCUtils.appGroupUserDefault) private var dim = 0.0

    var body: some View {
        if let image = store.image {
            LCWallpaperImageView(image: image, scale: scale, offset: CGSize(width: offsetX, height: offsetY), dim: dim)
        }
    }
}

// MARK: - Adjust screen

/// Full-screen preview: pinch to zoom, drag to move, slider to dim. Nothing is saved until Done.
struct LCWallpaperAdjustView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LCWallpaperKeys.scale, store: LCUtils.appGroupUserDefault) private var savedScale = 1.0
    @AppStorage(LCWallpaperKeys.offsetX, store: LCUtils.appGroupUserDefault) private var savedOffsetX = 0.0
    @AppStorage(LCWallpaperKeys.offsetY, store: LCUtils.appGroupUserDefault) private var savedOffsetY = 0.0
    @AppStorage(LCWallpaperKeys.dim, store: LCUtils.appGroupUserDefault) private var savedDim = 0.0

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dim: Double = 0
    @State private var gestureStartScale: CGFloat?
    @State private var gestureStartOffset: CGSize?
    @State private var loaded = false

    var body: some View {
        ZStack {
            // Full screen, like the app list background, so the saved numbers mean the same thing there.
            GeometryReader { geometry in
                let layout = LCWallpaperGeometry(imageSize: image.size, container: geometry.size)
                LCWallpaperImageView(image: image, scale: scale, offset: offset, dim: dim)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(layout: layout, container: geometry.size)
                        .simultaneously(with: zoomGesture(layout: layout)))
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button("lc.common.cancel".loc) { dismiss() }
                    Spacer()
                    Button("lc.settings.homeScreen.wallpaperReset".loc) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            scale = 1
                            offset = .zero
                        }
                    }
                    Spacer()
                    Button("lc.common.done".loc) { save() }
                        .font(.body.bold())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 16)

                Spacer()

                VStack(spacing: 8) {
                    Text("lc.settings.homeScreen.wallpaperAdjustHint".loc)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "sun.max")
                        Slider(value: $dim, in: 0...LCWallpaperKeys.maxDim)
                            .accessibilityLabel("lc.settings.homeScreen.wallpaperDim".loc)
                        Image(systemName: "sun.min")
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .environment(\.colorScheme, .dark)
        }
        .statusBarHidden()
        .onAppear {
            guard !loaded else { return }
            loaded = true
            scale = CGFloat(savedScale)
            offset = CGSize(width: savedOffsetX, height: savedOffsetY)
            dim = savedDim
        }
    }

    private func dragGesture(layout: LCWallpaperGeometry, container: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = gestureStartOffset ?? offset
                gestureStartOffset = start
                guard container.width > 0, container.height > 0 else { return }
                let proposed = CGSize(width: start.width + value.translation.width / container.width,
                                      height: start.height + value.translation.height / container.height)
                // Clamp as we go so the drag stops at the edge instead of building up hidden slack.
                offset = layout.clampedNormalized(scale: scale, normalized: proposed)
            }
            .onEnded { _ in
                gestureStartOffset = nil
            }
    }

    private func zoomGesture(layout: LCWallpaperGeometry) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let start = gestureStartScale ?? scale
                gestureStartScale = start
                scale = min(max(start * value, 1), LCWallpaperKeys.maxScale)
                offset = layout.clampedNormalized(scale: scale, normalized: offset)
            }
            .onEnded { _ in
                gestureStartScale = nil
            }
    }

    private func save() {
        savedScale = Double(scale)
        savedOffsetX = Double(offset.width)
        savedOffsetY = Double(offset.height)
        savedDim = dim
        dismiss()
    }
}

// MARK: - Photo picker

/// PHPicker wrapper (PhotosPicker needs iOS 16; we support 15). Needs no photo library permission.
struct LCWallpaperPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: LCWallpaperPicker
        init(_ parent: LCWallpaperPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                parent.isPresented = false
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self.parent.onPick(image)
                    }
                    self.parent.isPresented = false
                }
            }
        }
    }
}

// MARK: - Settings rows

/// Wallpaper rows for Settings > Home Screen.
struct LCWallpaperSettingsRows: View {
    @ObservedObject private var store = LCWallpaperStore.shared
    @State private var showPicker = false
    @State private var showAdjust = false
    @State private var adjustAfterPick = false
    @State private var errorInfo: String?

    var body: some View {
        Group {
            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(store.image == nil ? "lc.settings.homeScreen.chooseWallpaper".loc : "lc.settings.homeScreen.changeWallpaper".loc)
                    Spacer()
                    if let image = store.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .accessibilityHidden(true)
                    }
                }
            }
            if store.image != nil {
                Button("lc.settings.homeScreen.adjustWallpaper".loc) {
                    showAdjust = true
                }
                Button("lc.settings.homeScreen.removeWallpaper".loc, role: .destructive) {
                    withAnimation { store.remove() }
                }
            }
        }
        .sheet(isPresented: $showPicker, onDismiss: {
            // Go straight to adjusting a freshly picked wallpaper.
            if adjustAfterPick {
                adjustAfterPick = false
                showAdjust = true
            }
        }) {
            LCWallpaperPicker(isPresented: $showPicker) { image in
                do {
                    try store.setImage(image)
                    adjustAfterPick = true
                } catch {
                    errorInfo = error.localizedDescription
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showAdjust) {
            if let image = store.image {
                LCWallpaperAdjustView(image: image)
            }
        }
        .alert("lc.common.error".loc, isPresented: Binding(get: { errorInfo != nil }, set: { if !$0 { errorInfo = nil } })) {
        } message: {
            Text(errorInfo ?? "")
        }
    }
}
