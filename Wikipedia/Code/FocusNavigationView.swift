import WMFComponents

protocol FocusNavigationViewDelegate: AnyObject {
    func focusNavigationViewDidTapClose(_ focusNavigationView: FocusNavigationView)
}

final class FocusNavigationView: UIView {

    @IBOutlet var titleLabelVerticalConstraints: [NSLayoutConstraint]!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var closeButton: UIButton!
    @IBOutlet private var divView: UIView!
    
    weak var delegate: FocusNavigationViewDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        closeButton.imageView?.contentMode = .center
        closeButton.setImage(WKSFSymbolIcon.for(symbol: .multiplyCircleFill), for: .normal)
    }
    
    func configure(titleText: String, closeButtonAccessibilityText: String, traitCollection: UITraitCollection, isTitleAccessible: Bool = false) {
       
        titleLabel.text = titleText
        titleLabel.isAccessibilityElement = isTitleAccessible
        titleLabel.font = WKFont.for(.semiboldHeadline, compatibleWith: traitCollection)
        closeButton.accessibilityLabel = closeButtonAccessibilityText
        
        updateLayout(for: traitCollection)
    }
    
    func updateLayout(for traitCollection: UITraitCollection) {
        titleLabelVerticalConstraints.forEach { (constraint) in
            constraint.constant = traitCollection.verticalSizeClass == .compact ? 5 : 15
        }
    }
    
    @IBAction func tappedClose() {
        delegate?.focusNavigationViewDidTapClose(self)
    }
    
}

extension FocusNavigationView: Themeable {
    func apply(theme: Theme) {
        titleLabel.textColor = theme.colors.primaryText
        closeButton.tintColor = theme.colors.secondaryText
        backgroundColor = theme.colors.paperBackground
        divView.backgroundColor = theme.colors.midBackground
    }
}
