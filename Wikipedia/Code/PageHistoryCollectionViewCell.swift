import UIKit

class PageHistoryCollectionViewCell: CollectionViewCell {
    private let roundedContent = UIView()
    private let editableContent = UIView()
    private let timeLabel = UILabel()
    private let sizeDiffLabel = UILabel()
    private let commentLabel = UILabel()
    private let authorButton = AlignedImageButton()
    private let selectView = BatchEditSelectView()
    private let spacing: CGFloat = 3
    private var theme = Theme.standard

    var time: String?

    var displayTime: String? {
        didSet {
            timeLabel.text = displayTime
            setNeedsLayout()
        }
    }

    var sizeDiff: Int? {
        didSet {
            guard let sizeDiff = sizeDiff else {
                sizeDiffLabel.isHidden = true
                return
            }
            sizeDiffLabel.isHidden = false
            let added = sizeDiff > 0
            sizeDiffLabel.text = added ? "+\(sizeDiff)" : "\(sizeDiff)"
            if added || sizeDiff == 0 {
                sizeDiffLabel.accessibilityLabel = String.localizedStringWithFormat(WMFLocalizedString("page-history-revision-size-diff-addition", value: "Added {{PLURAL:%1$d|%1$d byte|%1$d bytes}}", comment: "Accessibility label text telling the user how many bytes were added in a revision - %1$@ is replaced with the number of bytes added in a revision"), sizeDiff)
            } else {
                sizeDiffLabel.accessibilityLabel = String.localizedStringWithFormat(WMFLocalizedString("page-history-revision-size-diff-subtraction", value: "Removed {{PLURAL:%1$d|%1$d byte|%1$d bytes}}", comment: "Accessibility label text telling the user how many bytes were removed in a revision - %1$d is replaced with the number of bytes removed in a revision"), abs(sizeDiff))
            }
            setNeedsLayout()
        }
    }

    var authorImage: UIImage? {
        didSet {
            setNeedsLayout()
        }
    }

    var author: String? {
        didSet {
            authorButton.setTitle(author, for: .normal)
            authorButton.accessibilityLabel = String.localizedStringWithFormat(WMFLocalizedString("page-history-revision-author-accessibility-label", value: "Author: %@", comment: "Accessibility label text telling the user who authored a revision"), author ?? WMFLocalizedString("unknown-generic-text", value: "Unknown", comment: "Default text used in places where no contextual information is provided"))
            setNeedsLayout()
        }
    }

    var comment: String? {
        didSet {
            setNeedsLayout()
        }
    }

    var isMinor: Bool = false {
        didSet {
            setNeedsLayout()
        }
    }

    private var isEditing = false {
        didSet {
            willStartEditing = false
            setNeedsLayout()
        }
    }

    private var isEditingEnabled = true {
        didSet {
            apply(theme: theme)
            setNeedsLayout()
        }
    }

    private var willStartEditing = false {
        didSet {
            setNeedsLayout()
        }
    }

    var selectionIndex: Int?
    var selectionThemeModel: PageHistoryCollectionViewCellSelectionThemeModel?

    func setEditing(_ editing: Bool, animated: Bool = true) {
        willStartEditing = editing
        selectView.isSelected = isSelected
        layoutIfNeeded()
        if animated {
            let animator = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
                self.isEditing = editing
                self.layoutIfNeeded()
            }
            let delayFactor: CGFloat = editing ? 0.05 : 0.25
            animator.addAnimations({
                self.selectView.setNeedsLayout()
                self.selectView.alpha = editing ? 1 : 0
            }, delayFactor: delayFactor)
            animator.startAnimation()
        } else {
            isEditing = editing
            selectView.setNeedsLayout()
            layoutIfNeeded()
            selectView.alpha = editing ? 1 : 0
        }
    }

    func enableEditing(_ enableEditing: Bool, animated: Bool = true) {
        guard !isSelected, isEditingEnabled != enableEditing else {
            return
        }
        layoutIfNeeded()
        if animated {
            let animator = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
                self.isEditingEnabled = enableEditing
                self.selectView.isSelectionDisabled = !enableEditing
                self.layoutIfNeeded()
            }
            animator.addAnimations({
                self.selectView.setNeedsLayout()
            }, delayFactor: 0.05)
            animator.startAnimation()
        } else {
            isEditingEnabled = enableEditing
            selectView.isSelectionDisabled = !enableEditing
            selectView.setNeedsLayout()
            layoutIfNeeded()
        }
    }

    override func setup() {
        super.setup()
        roundedContent.layer.cornerRadius = 6
        roundedContent.layer.masksToBounds = true
        roundedContent.layer.borderWidth = 1

        editableContent.addSubview(timeLabel)
        editableContent.addSubview(sizeDiffLabel)
        authorButton.horizontalSpacing = 8
        authorButton.isUserInteractionEnabled = false
        editableContent.addSubview(authorButton)
        commentLabel.numberOfLines = 2
        commentLabel.lineBreakMode = .byTruncatingTail
        editableContent.addSubview(commentLabel)
        selectView.alpha = 0
        selectView.clipsToBounds = true
        roundedContent.addSubview(selectView)
        roundedContent.addSubview(editableContent)
        contentView.addSubview(roundedContent)
        accessibilityElements = [timeLabel, sizeDiffLabel, authorButton, commentLabel]
    }

    override func reset() {
        super.reset()
        isEditing = false
        willStartEditing = false
        isEditingEnabled = true
        selectView.isSelectionDisabled = false
        selectionThemeModel = nil
        selectionIndex = nil
    }

    override func updateFonts(with traitCollection: UITraitCollection) {
        super.updateFonts(with: traitCollection)
        timeLabel.font = UIFont.wmf_font(.semiboldSubheadline, compatibleWithTraitCollection: traitCollection)
        sizeDiffLabel.font = UIFont.wmf_font(.semiboldSubheadline, compatibleWithTraitCollection: traitCollection)
        authorButton.titleLabel?.font = UIFont.wmf_font(.footnote, compatibleWithTraitCollection: traitCollection)
        commentLabel.font = UIFont.wmf_font(.footnote, compatibleWithTraitCollection: traitCollection)
    }

    override var isSelected: Bool {
        didSet {
            guard isEditing else {
                return
            }
            selectView.isSelected = isSelected
        }
    }

    override func sizeThatFits(_ size: CGSize, apply: Bool) -> CGSize {
        let size = super.sizeThatFits(size, apply: apply)
        let layoutMargins = calculatedLayoutMargins

        let widthMinusMargins = layoutWidth(for: size)

        roundedContent.frame = CGRect(x: layoutMargins.left, y: 0, width: widthMinusMargins, height: bounds.height)
        editableContent.frame = CGRect(x: 0, y: 0, width: widthMinusMargins, height: bounds.height)

        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let semanticContentAttribute: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        if willStartEditing {
            let x = isRTL ? roundedContent.frame.maxX : 0
            selectView.frame = CGRect(x: x, y: 0, width: 30, height: bounds.height)
        } else if isEditing {
            let spaceOccupiedBySelectView = selectView.frame.width * 2
            let x = isRTL ? widthMinusMargins - spaceOccupiedBySelectView : roundedContent.frame.origin.x
            selectView.frame.origin = CGPoint(x: x, y: 0)
            selectView.layoutIfNeeded()
            let editableContentX = isRTL ? 0 : editableContent.frame.origin.x + spaceOccupiedBySelectView
            editableContent.frame = CGRect(x: editableContentX, y: 0, width: widthMinusMargins - spaceOccupiedBySelectView, height: bounds.height)
        } else {
            let x = isRTL ? roundedContent.frame.maxX : 0
            selectView.frame.origin = CGPoint(x: x, y: 0)
            editableContent.frame = CGRect(x: 0, y: 0, width: widthMinusMargins, height: bounds.height)
        }

        let availableWidth = editableContent.frame.width - layoutMargins.right - layoutMargins.left
        let leadingPaneAvailableWidth = availableWidth / 3
        let trailingPaneAvailableWidth = availableWidth - leadingPaneAvailableWidth

        var leadingPaneOrigin = CGPoint(x: isRTL ? availableWidth - leadingPaneAvailableWidth : layoutMargins.left, y: layoutMargins.top)
        var trailingPaneOrigin = CGPoint(x: isRTL ? layoutMargins.left : layoutMargins.left + leadingPaneAvailableWidth, y: layoutMargins.top)

        if timeLabel.wmf_hasText {
            let timeLabelFrame = timeLabel.wmf_preferredFrame(at: leadingPaneOrigin, maximumWidth: leadingPaneAvailableWidth, alignedBy: semanticContentAttribute, apply: apply)
            leadingPaneOrigin.y += timeLabelFrame.layoutHeight(with: spacing * 2)
            timeLabel.isHidden = false
        } else {
            timeLabel.isHidden = true
        }

        if sizeDiffLabel.wmf_hasText {
            let sizeDiffLabelFrame = sizeDiffLabel.wmf_preferredFrame(at: leadingPaneOrigin, maximumWidth: leadingPaneAvailableWidth, alignedBy: semanticContentAttribute, apply: apply)
            leadingPaneOrigin.y += sizeDiffLabelFrame.layoutHeight(with: spacing)
            sizeDiffLabel.isHidden = false
        } else {
            sizeDiffLabel.isHidden = true
        }

        if authorButton.titleLabel?.wmf_hasText ?? false {
            if apply {
                authorButton.setImage(authorImage, for: .normal)
            }
            let authorButtonFrame = authorButton.wmf_preferredFrame(at: trailingPaneOrigin, maximumWidth: trailingPaneAvailableWidth, alignedBy: semanticContentAttribute, apply: apply)
            trailingPaneOrigin.y += authorButtonFrame.layoutHeight(with: spacing * 3)
            authorButton.isHidden = false
        } else {
            authorButton.isHidden = true
        }

        if let comment = comment {
            // TODO: Adjust icons for themes
            if isMinor, let minorImage = UIImage(named: "minor-edit") {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = minorImage
                let attributedText = NSMutableAttributedString(attachment: imageAttachment)
                attributedText.append(NSAttributedString(string: " \(comment)"))
                commentLabel.attributedText = attributedText
            } else {
                commentLabel.text = comment
            }
            // TODO: Make sure all icons have the same sizes
            let commentLabelFrame = commentLabel.wmf_preferredFrame(at: trailingPaneOrigin, maximumWidth: trailingPaneAvailableWidth, alignedBy: semanticContentAttribute, apply: apply)
            trailingPaneOrigin.y += commentLabelFrame.layoutHeight(with: spacing)
            commentLabel.isHidden = false
        } else {
            commentLabel.isHidden = true
        }
        return CGSize(width: size.width, height: max(leadingPaneOrigin.y, trailingPaneOrigin.y) + layoutMargins.bottom)
    }
}

extension PageHistoryCollectionViewCell: Themeable {
    func apply(theme: Theme) {
        self.theme = theme

        if let selectionThemeModel = selectionThemeModel {
            selectView.selectedImage = selectionThemeModel.selectedImage
            roundedContent.layer.borderColor = selectionThemeModel.borderColor.cgColor
            roundedContent.backgroundColor = selectionThemeModel.backgroundColor
            authorButton.setTitleColor(selectionThemeModel.authorColor, for: .normal)
            authorButton.tintColor = selectionThemeModel.authorColor
            commentLabel.textColor = selectionThemeModel.commentColor
            timeLabel.textColor = selectionThemeModel.timeColor

            if let sizeDiff = sizeDiff {
                if sizeDiff == 0 {
                    sizeDiffLabel.textColor = selectionThemeModel.sizeDiffNoDifferenceColor
                } else if sizeDiff > 0 {
                    sizeDiffLabel.textColor = selectionThemeModel.sizeDiffAdditionColor
                } else {
                    sizeDiffLabel.textColor = selectionThemeModel.sizeDiffSubtractionColor
                }
            }
        } else {
            roundedContent.layer.borderColor = theme.colors.border.cgColor
            roundedContent.backgroundColor = theme.colors.paperBackground
            authorButton.setTitleColor(theme.colors.link, for: .normal)
            authorButton.tintColor = theme.colors.link
            commentLabel.textColor = theme.colors.primaryText
            timeLabel.textColor = theme.colors.secondaryText

            if let sizeDiff = sizeDiff {
                if sizeDiff == 0 {
                    sizeDiffLabel.textColor = theme.colors.link
                } else if sizeDiff > 0 {
                    sizeDiffLabel.textColor = theme.colors.accent
                } else {
                    sizeDiffLabel.textColor = theme.colors.destructive
                }
            }
        }
    }
}