//
//  LCAppIconView.swift
//  LiveContainerSwiftUI
//
//  Home screen style app cell: icon + name, with a small shared-app badge.
//

import Foundation
import UIKit

final class LCAppIconRootView: UIView {
    static let labelSpacing: CGFloat = 6
    static let labelFont = UIFont.systemFont(ofSize: 12, weight: .regular)

    /// Total height of a cell for the given icon size.
    static func cellHeight(iconSize: CGFloat) -> CGFloat {
        return iconSize + labelSpacing + ceil(labelFont.lineHeight)
    }

    let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let sharedBadge = LCAppIconBadgeView(symbolName: "arrowshape.turn.up.left.fill")
    private let signingOverlay = LCAppIconProgressOverlay()

    private var iconWidthConstraint: NSLayoutConstraint!
    private var iconHeightConstraint: NSLayoutConstraint!
    private(set) var iconSize: CGFloat = 60
    private var baseIconAlpha: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isOpaque = false
        backgroundColor = .clear

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerCurve = .continuous
        iconImageView.clipsToBounds = true
        iconImageView.isAccessibilityElement = false

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = Self.labelFont
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isAccessibilityElement = false

        signingOverlay.translatesAutoresizingMaskIntoConstraints = false
        signingOverlay.isHidden = true

        addSubview(iconImageView)
        addSubview(signingOverlay)
        addSubview(nameLabel)
        addSubview(sharedBadge)

        iconWidthConstraint = iconImageView.widthAnchor.constraint(equalToConstant: iconSize)
        iconHeightConstraint = iconImageView.heightAnchor.constraint(equalToConstant: iconSize)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconWidthConstraint,
            iconHeightConstraint,

            signingOverlay.leadingAnchor.constraint(equalTo: iconImageView.leadingAnchor),
            signingOverlay.trailingAnchor.constraint(equalTo: iconImageView.trailingAnchor),
            signingOverlay.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            signingOverlay.bottomAnchor.constraint(equalTo: iconImageView.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: Self.labelSpacing),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            nameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            sharedBadge.centerXAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: -3),
            sharedBadge.centerYAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: -3)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        applyIconSize()
    }

    private func applyIconSize() {
        iconWidthConstraint.constant = iconSize
        iconHeightConstraint.constant = iconSize
        // Matches the iOS home screen icon corner radius ratio.
        let cornerRadius = iconSize * 0.225
        iconImageView.layer.cornerRadius = cornerRadius
        signingOverlay.layer.cornerRadius = cornerRadius
    }

    /// Path matching the visible icon shape, used for context menu and drag previews.
    var iconPreviewPath: UIBezierPath {
        return UIBezierPath(roundedRect: iconImageView.bounds, cornerRadius: iconImageView.layer.cornerRadius)
    }

    func update(model: LCAppModel, appInfo: LCAppInfo, darkModeIcon: Bool, iconSize: CGFloat) {
        if self.iconSize != iconSize {
            self.iconSize = iconSize
            applyIconSize()
        }

        iconImageView.image = appInfo.iconIsDarkIcon(darkModeIcon) ?? UIImage()
        nameLabel.text = model.displayName

        sharedBadge.isHidden = !model.uiIsShared
        sharedBadge.fillColor = UIColor(named: "BadgeColor") ?? .systemOrange

        signingOverlay.isHidden = !model.isSigningInProgress
        signingOverlay.progress = model.signProgress
        baseIconAlpha = model.isAppRunning ? 0.6 : 1
        iconImageView.alpha = baseIconAlpha

        accessibilityLabel = model.displayName
        accessibilityTraits = model.isAppRunning ? [.button, .notEnabled] : .button
    }

    // MARK: - Touch highlight (dims the icon while pressed, like the home screen)

    private func setHighlighted(_ highlighted: Bool) {
        UIView.animate(withDuration: highlighted ? 0.05 : 0.2) {
            self.iconImageView.transform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            self.iconImageView.alpha = highlighted ? self.baseIconAlpha * 0.7 : self.baseIconAlpha
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        setHighlighted(true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        setHighlighted(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        setHighlighted(false)
    }
}

/// Small circular badge pinned to the bottom-right corner of the icon.
private final class LCAppIconBadgeView: UIView {
    static let size: CGFloat = 20

    private let imageView: UIImageView

    var fillColor: UIColor = .systemOrange {
        didSet { backgroundColor = fillColor }
    }

    init(symbolName: String) {
        imageView = UIImageView(image: UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        ))
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = fillColor
        layer.cornerRadius = Self.size / 2
        layer.borderWidth = 2
        clipsToBounds = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .white
        imageView.contentMode = .center
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateBorderColor()
    }

    // The ring separates the badge from the icon using the page background color.
    private func updateBorderColor() {
        layer.borderColor = UIColor.systemBackground.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBorderColor()
    }
}

/// Dimmed overlay with a progress ring, shown while the app is being signed.
private final class LCAppIconProgressOverlay: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    var progress: Double = 0 {
        didSet { progressLayer.strokeEnd = CGFloat(min(max(progress, 0), 1)) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.45)
        layer.cornerCurve = .continuous
        clipsToBounds = true
        isUserInteractionEnabled = false

        for shapeLayer in [trackLayer, progressLayer] {
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = 3
            shapeLayer.lineCap = .round
            layer.addSublayer(shapeLayer)
        }
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.strokeEnd = 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(bounds.width, bounds.height) * 0.22
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        ).cgPath
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.path = path
        progressLayer.path = path
    }
}
