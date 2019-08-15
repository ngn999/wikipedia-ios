import UIKit

@objc(WMFPageHistoryViewControllerDelegate)
protocol PageHistoryViewControllerDelegate: AnyObject {
    func pageHistoryViewControllerDidDisappear(_ pageHistoryViewController: PageHistoryViewController)
}

@objc(WMFPageHistoryViewController)
class PageHistoryViewController: ColumnarCollectionViewController {
    private let pageTitle: String
    private let pageURL: URL

    private let pageHistoryFetcher = PageHistoryFetcher()
    private var pageHistoryFetcherParams: PageHistoryRequestParameters

    private var batchComplete = false
    private var isLoadingData = false

    var shouldLoadNewData: Bool {
        if batchComplete || isLoadingData {
            return false
        }
        let maxY = collectionView.contentOffset.y + collectionView.frame.size.height + 200.0;
        if (maxY >= collectionView.contentSize.height) {
            return true
        }
        return false;
    }

    @objc public weak var delegate: PageHistoryViewControllerDelegate?

    private lazy var statsViewController = PageHistoryStatsViewController(pageTitle: pageTitle, locale: NSLocale.wmf_locale(for: pageURL.wmf_language))

    @objc init(pageTitle: String, pageURL: URL) {
        self.pageTitle = pageTitle
        self.pageURL = pageURL
        self.pageHistoryFetcherParams = PageHistoryRequestParameters(title: pageTitle)
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var pageHistorySections: [PageHistorySection] = []

    override var headerStyle: ColumnarCollectionViewController.HeaderStyle {
        return .sections
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: WMFLocalizedString("page-history-compare-title", value: "Compare", comment: "Title for action button that allows users to contrast different items"), style: .plain, target: self, action: #selector(compare(_:)))
        title = CommonStrings.historyTabTitle

        addChild(statsViewController)
        navigationBar.addUnderNavigationBarView(statsViewController.view)
        navigationBar.shadowColorKeyPath = \Theme.colors.border
        statsViewController.didMove(toParent: self)

        collectionView.register(PageHistoryCollectionViewCell.self, forCellWithReuseIdentifier: PageHistoryCollectionViewCell.identifier)
        collectionView.dataSource = self
        view.wmf_addSubviewWithConstraintsToEdges(collectionView)

        apply(theme: theme)

        // TODO: Move networking

        pageHistoryFetcher.fetchPageStats(pageTitle, pageURL: pageURL) { result in
            switch result {
            case .failure(let error):
                // TODO: Handle error
                print(error)
            case .success(let pageStats):
                DispatchQueue.main.async {
                    self.statsViewController.pageStats = pageStats
                }
            }
        }

        getPageHistory()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        delegate?.pageHistoryViewControllerDidDisappear(self)
    }

    private func getPageHistory() {
        isLoadingData = true

        pageHistoryFetcher.fetchRevisionInfo(pageURL, requestParams: pageHistoryFetcherParams, failure: { error in
            print(error)
            self.isLoadingData = false
        }) { results in
            self.pageHistorySections.append(contentsOf: results.items())
            self.pageHistoryFetcherParams = results.getPageHistoryRequestParameters(self.pageURL)
            self.batchComplete = results.batchComplete()
            self.isLoadingData = false
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        guard shouldLoadNewData else {
            return
        }
        getPageHistory()
    }

    @objc private func compare(_ sender: UIBarButtonItem) {

    }

    override func apply(theme: Theme) {
        super.apply(theme: theme)
        guard viewIfLoaded != nil else {
            self.theme = theme
            return
        }
        view.backgroundColor = theme.colors.paperBackground
        collectionView.backgroundColor = view.backgroundColor
        navigationItem.rightBarButtonItem?.tintColor = theme.colors.link
        navigationItem.leftBarButtonItem?.tintColor = theme.colors.primaryText
        statsViewController.apply(theme: theme)
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return pageHistorySections.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pageHistorySections[section].items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PageHistoryCollectionViewCell.identifier, for: indexPath) as? PageHistoryCollectionViewCell else {
            return UICollectionViewCell()
        }
        let item = pageHistorySections[indexPath.section].items[indexPath.item]
        if let date = item.revisionDate {
            // TODO: Local to UTC
            cell.time = DateFormatter.wmf_shortTime()?.string(from: date)
        }
        // TODO: Use logged-in icon when available
        cell.authorImage = item.isAnon ? UIImage(named: "bot") : UIImage(named: "anon")
        cell.author = item.user
        cell.sizeDiff = item.revisionSize > 0 ? "+\(item.revisionSize)" : "\(item.revisionSize)"
        cell.comment = item.parsedComment?.removingHTML
        cell.apply(theme: theme)
        return cell
    }

    override func configure(header: CollectionViewHeader, forSectionAt sectionIndex: Int, layoutOnly: Bool) {
        header.style = .pageHistory
        header.title = pageHistorySections[sectionIndex].sectionTitle
        header.titleTextColorKeyPath = \Theme.colors.secondaryText
        header.apply(theme: theme)
    }

    // MARK: Layout

    override func metrics(with boundsSize: CGSize, readableWidth: CGFloat, layoutMargins: UIEdgeInsets) -> ColumnarCollectionViewLayoutMetrics {
        return ColumnarCollectionViewLayoutMetrics.tableViewMetrics(with: boundsSize, readableWidth: readableWidth, layoutMargins: layoutMargins, interSectionSpacing: 0, interItemSpacing: 20)
    }
}
