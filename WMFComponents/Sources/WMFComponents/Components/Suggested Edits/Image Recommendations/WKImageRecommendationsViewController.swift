import SwiftUI
import UIKit
import WMFData
import Combine

public protocol WKImageRecommendationsDelegate: AnyObject {
    func imageRecommendationsUserDidTapViewArticle(project: WKProject, title: String)
    func imageRecommendationsUserDidTapImageLink(commonsURL: URL)
    func imageRecommendationsUserDidTapImage(project: WKProject, data: WKImageRecommendationsViewModel.WKImageRecommendationData, presentingVC: UIViewController)
    func imageRecommendationsUserDidTapInsertImage(viewModel: WKImageRecommendationsViewModel, title: String, with imageData: WKImageRecommendationsViewModel.WKImageRecommendationData)
    func imageRecommendationsUserDidTapLearnMore(url: URL?)
    func imageRecommendationsUserDidTapReportIssue()
    func imageRecommendationsDidTriggerError(_ error: Error)
    func imageRecommendationsDidTriggerTimeWarning()
    func imageRecommendationDidTriggerAltTextExperimentPanel(isFlowB: Bool, imageRecommendationsViewController: WKImageRecommendationsViewController)
}

public protocol WKImageRecommendationsLoggingDelegate: AnyObject {
    func logOnboardingDidTapPrimaryButton()
    func logOnboardingDidTapSecondaryButton()
    func logTooltipsDidTapFirstNext()
    func logTooltipsDidTapSecondNext()
    func logTooltipsDidTapThirdOK()
    func logBottomSheetDidAppear()
    func logBottomSheetDidTapYes()
    func logBottomSheetDidTapNo()
    func logBottomSheetDidTapNotSure()
    func logOverflowDidTapLearnMore()
    func logOverflowDidTapTutorial()
    func logOverflowDidTapProblem()
    func logBottomSheetDidTapFileName()
    func logRejectSurveyDidAppear()
    func logRejectSurveyDidTapCancel()
    func logRejectSurveyDidTapSubmit(rejectionReasons: [String], otherReason: String?, fileName: String, recommendationSource: String)
    func logEmptyStateDidAppear()
    func logEmptyStateDidTapBack()
    func logDialogWarningMessageDidDisplay(fileName: String, recommendationSource: String)
}

fileprivate final class WKImageRecommendationsHostingViewController: WKComponentHostingController<WKImageRecommendationsView> {

    init(viewModel: WKImageRecommendationsViewModel, delegate: WKImageRecommendationsDelegate, loggingDelegate: WKImageRecommendationsLoggingDelegate, tooltipGeometryValues: WKTooltipGeometryValues) {
        let rootView = WKImageRecommendationsView(viewModel: viewModel, tooltipGeometryValues: tooltipGeometryValues, errorTryAgainAction: {
            
            viewModel.tryAgainAfterLoadingError()
            
        }, viewArticleAction: { [weak delegate] title in
            
            delegate?.imageRecommendationsUserDidTapViewArticle(project: viewModel.project, title: title)
            
        }, emptyViewAppearanceAction: { [weak loggingDelegate] in
            
            loggingDelegate?.logEmptyStateDidAppear()
            
        })
        super.init(rootView: rootView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public final class WKImageRecommendationsViewController: WKCanvasViewController {

    // MARK: - Properties

    fileprivate let hostingViewController: WKImageRecommendationsHostingViewController
    private weak var delegate: WKImageRecommendationsDelegate?
    private weak var loggingDelegate: WKImageRecommendationsLoggingDelegate?
    @ObservedObject private var viewModel: WKImageRecommendationsViewModel
    private var imageRecommendationBottomSheetController: WKImageRecommendationsBottomSheetViewController
    private var cancellables = Set<AnyCancellable>()

    private var overflowMenu: UIMenu {

        let learnMore = UIAction(title: viewModel.localizedStrings.learnMoreButtonTitle, image: UIImage(systemName: "info.circle"), handler: { [weak self] _ in
            self?.loggingDelegate?.logOverflowDidTapLearnMore()
            self?.goToFAQ()
        })
        let tutorial = UIAction(title: viewModel.localizedStrings.tutorialButtonTitle, image: UIImage(systemName: "lightbulb.min"), handler: { [weak self] _ in
            self?.loggingDelegate?.logOverflowDidTapTutorial()
            self?.showTutorial()
        })

        let reportIssues = UIAction(title: viewModel.localizedStrings.problemWithFeatureButtonTitle, image: UIImage(systemName: "flag"), handler: { [weak self] _ in
            self?.loggingDelegate?.logOverflowDidTapProblem()
            self?.reportIssue()
        })

        let menuItems: [UIMenuElement] = [learnMore, tutorial, reportIssues]

        return UIMenu(title: String(), children: menuItems)
    }

    // MARK: Lifecycle

    private let dataController = WMFImageRecommendationsDataController()
    private let tooltipGeometryValues = WKTooltipGeometryValues()

    public init(viewModel: WKImageRecommendationsViewModel, delegate: WKImageRecommendationsDelegate, loggingDelegate: WKImageRecommendationsLoggingDelegate) {
        self.hostingViewController = WKImageRecommendationsHostingViewController(viewModel: viewModel, delegate: delegate, loggingDelegate: loggingDelegate, tooltipGeometryValues: tooltipGeometryValues)
        self.delegate = delegate
        self.loggingDelegate = loggingDelegate
        self.viewModel = viewModel
        self.imageRecommendationBottomSheetController = WKImageRecommendationsBottomSheetViewController(viewModel: viewModel, delegate: delegate, loggingDelegate: loggingDelegate)
        super.init()
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.localizedStrings.title
        navigationItem.backButtonDisplayMode = .generic
        setupOverflowMenu()
        addComponent(hostingViewController, pinToEdges: true)

        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        let image = WKSFSymbolIcon.for(symbol: .chevronBackward, font: .boldCallout)
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(tappedBack))
    }


    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bindViewModel()

        if !dataController.hasPresentedOnboardingModal {
            presentOnboardingIfNecessary()
        } else {
            viewModel.fetchImageRecommendationsIfNeeded {

            }
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        imageRecommendationBottomSheetController.dismiss(animated: true)
        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables.removeAll()
    }
    
    public func presentImageRecommendationBottomSheet() {
        imageRecommendationBottomSheetController.isModalInPresentation = true
        if let bottomSheet = imageRecommendationBottomSheetController.sheetPresentationController {
            bottomSheet.detents = [.medium(), .large()]
            bottomSheet.largestUndimmedDetentIdentifier = .medium
            bottomSheet.prefersGrabberVisible = true
            bottomSheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }

        navigationController?.present(imageRecommendationBottomSheetController, animated: true, completion: {

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in

                guard let self else {
                    return
                }

                self.presentTooltipsIfNecessary(onBottomSheetViewController: self.imageRecommendationBottomSheetController)
            }

        })
    }

    // MARK: Private methods
    
    private func shouldShowAltTextExperimentModal() -> Bool {
        guard let lastRecommendation = viewModel.lastRecommendation,
            lastRecommendation.altText == nil,
            lastRecommendation.lastRevisionID != nil else {
           return false
        }

        let dataController = WMFAltTextDataController.shared

        guard let dataController else {
            return false
        }

        let isLoggedIn = viewModel.isLoggedIn

        do {
            try dataController.assignImageRecsExperiment(isLoggedIn: isLoggedIn, project: viewModel.project)
        } catch let error {
            debugPrint(error)
            return false
        }

        if dataController.shouldEnterAltTextImageRecommendationsFlow(isLoggedIn: isLoggedIn, project: viewModel.project) {
            return true
        }

        return false
    }

    @objc private func tappedBack() {

        if viewModel.imageRecommendations.isEmpty && viewModel.loadingError == nil {
            loggingDelegate?.logEmptyStateDidTapBack()
        }

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.popViewController(animated: true)
    }

    private func setupOverflowMenu() {
        let rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), primaryAction: nil, menu: overflowMenu)
        navigationItem.rightBarButtonItem = rightBarButtonItem
        rightBarButtonItem.tintColor = theme.link
    }

    private func presentTooltipsIfNecessary(onBottomSheetViewController bottomSheetViewController: WKImageRecommendationsBottomSheetViewController, force: Bool = false) {

        // Do not present tooltips in empty or loading state
        if viewModel.loading || viewModel.imageRecommendations.isEmpty || viewModel.loadingError != nil {
            return
        }

        if !force && dataController.hasPresentedOnboardingTooltips {
            return
        }

        guard let hostingView = hostingViewController.view,
              let bottomSheetView = bottomSheetViewController.bottomSheetView else {
            return
        }

        let divGlobalFrame = tooltipGeometryValues.articleSummaryDivGlobalFrame
        let articleSummaryDivSourceRect: CGRect

        // Article Summary div frame comes through as global / window coordinates. We need to offset them against the hosting view frame to send in an accurate sourceRect.
        let hostingViewGlobalOrigin = hostingView.superview?.convert(hostingView.frame.origin, to: nil)
        if let hostingViewGlobalOrigin {
            let xOffset = CGFloat(25)
            articleSummaryDivSourceRect = CGRect(x: (divGlobalFrame.minX - hostingViewGlobalOrigin.x) + xOffset, y: divGlobalFrame.maxY - hostingViewGlobalOrigin.y, width: 0, height: 0)
        } else {
            articleSummaryDivSourceRect = divGlobalFrame
        }

        let viewModel1 = WKTooltipViewModel(localizedStrings: viewModel.localizedStrings.firstTooltipStrings, buttonNeedsDisclosure: true, sourceView: hostingView, sourceRect: articleSummaryDivSourceRect, permittedArrowDirections: .up) { [weak self] in
            self?.loggingDelegate?.logTooltipsDidTapFirstNext()
        }

        let viewModel2 = WKTooltipViewModel(localizedStrings: viewModel.localizedStrings.secondTooltipStrings, buttonNeedsDisclosure: true, sourceView: bottomSheetView, sourceRect: bottomSheetView.bounds) { [weak self] in
            self?.loggingDelegate?.logTooltipsDidTapSecondNext()
        }

        let viewModel3 = WKTooltipViewModel(localizedStrings: viewModel.localizedStrings.thirdTooltipStrings, buttonNeedsDisclosure: false, sourceView: bottomSheetView, sourceRect: bottomSheetView.toolbar.frame) { [weak self] in
            self?.loggingDelegate?.logTooltipsDidTapThirdOK()
        }

        bottomSheetViewController.displayTooltips(tooltipViewModels: [viewModel1, viewModel2, viewModel3])

        if !force {
            dataController.hasPresentedOnboardingTooltips = true
        }
    }

    private func presentOnboardingIfNecessary() {
        guard !dataController.hasPresentedOnboardingModal else {
            return
        }

        let firstItem = WKOnboardingViewModel.WKOnboardingCellViewModel(icon: WKSFSymbolIcon.for(symbol: .photoOnRectangleAngled), title: viewModel.localizedStrings.onboardingStrings.firstItemTitle, subtitle: viewModel.localizedStrings.onboardingStrings.firstItemBody, fillIconBackground: true)

        let secondItem = WKOnboardingViewModel.WKOnboardingCellViewModel(icon: WKSFSymbolIcon.for(symbol: .plusForwardSlashMinus), title: viewModel.localizedStrings.onboardingStrings.secondItemTitle, subtitle: viewModel.localizedStrings.onboardingStrings.secondItemBody, fillIconBackground: true)

        let thirdItem = WKOnboardingViewModel.WKOnboardingCellViewModel(icon: WKIcon.commons, title: viewModel.localizedStrings.onboardingStrings.thirdItemTitle, subtitle: viewModel.localizedStrings.onboardingStrings.thirdItemBody, fillIconBackground: true)

        let onboardingViewModel = WKOnboardingViewModel(title: viewModel.localizedStrings.onboardingStrings.title, cells: [firstItem, secondItem, thirdItem], primaryButtonTitle: viewModel.localizedStrings.onboardingStrings.continueButton, secondaryButtonTitle: viewModel.localizedStrings.onboardingStrings.learnMoreButton)

        let onboardingController = WKOnboardingViewController(viewModel: onboardingViewModel)
        onboardingController.delegate = self
        present(onboardingController, animated: true, completion: {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        })

        dataController.hasPresentedOnboardingModal = true
    }

    private func bindViewModel() {
        viewModel.$debouncedLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                
                guard let self else {
                    return
                }
                
                
                if !isLoading {
                    if self.viewModel.currentRecommendation?.articleSummary != nil {
                        if self.shouldShowAltTextExperimentModal() {
                            self.delegate?.imageRecommendationDidTriggerAltTextExperimentPanel(isFlowB: true, imageRecommendationsViewController: self)
                        } else {
                            self.presentImageRecommendationBottomSheet()
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        viewModel.$loadingError
            .receive(on: RunLoop.main)
            .sink { [weak self] loadingError in
                if let loadingError {
                    self?.delegate?.imageRecommendationsDidTriggerError(loadingError)
                }
            }
            .store(in: &cancellables)
    }

    private func showTutorial() {
        presentTooltipsIfNecessary(onBottomSheetViewController: imageRecommendationBottomSheetController, force: true)
    }

    private func goToFAQ() {
        delegate?.imageRecommendationsUserDidTapLearnMore(url: viewModel.learnMoreURL)
    }

    private func reportIssue() {
        delegate?.imageRecommendationsUserDidTapReportIssue()
    }
}

extension WKImageRecommendationsViewController: WKOnboardingViewDelegate {

    public func onboardingViewDidClickPrimaryButton() {
        presentedViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.viewModel.fetchImageRecommendationsIfNeeded {

            }
        })

        loggingDelegate?.logOnboardingDidTapPrimaryButton()
    }

    public func onboardingViewDidClickSecondaryButton() {
        guard let url = viewModel.learnMoreURL else {
            return
        }

        UIApplication.shared.open(url)

        loggingDelegate?.logOnboardingDidTapSecondaryButton()
    }

    public func onboardingViewWillSwipeToDismiss() {
        viewModel.fetchImageRecommendationsIfNeeded {

        }
    }
}

