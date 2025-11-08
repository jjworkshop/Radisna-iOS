//
//  TimetableView.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit

class TimetableView: CommonView {
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var stationFrameView: UIView!
    
    @IBOutlet weak var extractionFrameView: UIView!
    @IBOutlet weak var searchwordField: UISearchBar!
    @IBOutlet weak var calendarButton: UIButton!
    @IBOutlet weak var weekLabel: UILabel!
    
    @IBOutlet weak var loadingLabel: LoadingLabel!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bImage: UIImageView!
    
    @IBOutlet weak var addFrameView: UIView!
    @IBOutlet weak var addCountLabel: UILabel!
    @IBOutlet weak var addCancelButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    
    
    @IBOutlet weak var addFrameHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var addFrameBottomConstraint: NSLayoutConstraint!
    
    weak var viewController: TimetableViewController?
    // UICollectionVIewに内包するセルのサイズキャッシュ
    var cellSizeCache: CGSize?
    let cellHeight:CGFloat = 68.0
    // フレッシュコントローラー
    let refreshControl = UIRefreshControl()
    
    private var stations = [String]()
    private var stationButtons: [ScrollFriendlyButton] = []
    private var lengthToBottom: CGFloat = 0.0
    
    // レイアウト完了処理
    override func firstlayoutSubviews() {
        // ボタンにアイコン設定
        let size = CGSize(width: 22, height: 22)
        leftButton.setImage(named: AppCom.pdf_circle_down, color: UIColor.label, size: size)
        rightButton.setImage(named: AppCom.pdf_filter_off, color: UIColor.systemGreen, size: size)
        calendarButton.setImage(named: AppCom.pdf_calendar, color: UIColor.label,
                                size: CGSize(width: 32, height: 32))
        // サーチバー関連
        searchwordField.backgroundImage = UIImage()    // Borderを消す
        searchwordField.enablesReturnKeyAutomatically = true   // 「検索」を空白の場合Disableにする
        searchwordField.placeholder = "番組検索"
        // 放送局選択UIの作成
        setupStationList()
        setupScrollView()
        // テーブルビュー設定
        tableView.register(UINib(nibName: "TimetableTableViewCell", bundle: nil), forCellReuseIdentifier: "TimetableCard")
        // テーブルビューのセパレータを消す
        tableView.separatorStyle = .none
        tableView.separatorInset = .zero
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.cellLayoutMarginsFollowReadableWidth = false
        // テーブルビューの高さ（全て同じ）を設定
        tableView.estimatedRowHeight = cellHeight
        tableView.rowHeight = cellHeight
        // テーブルビューのマージンを設定
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: 69.0, right: 0)
        tableView.contentInset = insets
        tableView.scrollIndicatorInsets = insets
        // テーブルビューにリフレッシュコントローラーを付ける
        tableView.refreshControl = refreshControl
        // ボトムのFrameを消す
        lengthToBottom = addFrameHeightConstraint.constant + Com.safeHightBottom
        addFrameBottomConstraint.constant = lengthToBottom
    }
    
    // 指定のセルを更新
    func updateCell(_ index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    // ボタンがタップされた
    private func onTapped(stationId: String) {
        if stations.firstIndex(of: stationId) != nil {
            viewController?.presenter.currentStationId = stationId
            updateStationButtonStyles()
            Com.XLOG("タップID: \(stationId)")
            viewController?.presenter.changedStationId.onNext(true)
        }
    }
    
    // ボトムのフレーム down (hide)
    func moveBottomFrameViewDown() {
        addFrameBottomConstraint.constant = lengthToBottom
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    
    // ボトムのフレーム up (show)
    func moveBottomFrameViewUp() {
        addFrameBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
}

// MARK: - 放送局アイコンボタン関連

extension TimetableView {
    // ボタンスタイルの変更
    private func updateStationButtonStyles() {
        for (_, button) in stationButtons.enumerated() {
            if button.stationId == viewController?.presenter.currentStationId {
                var config = UIButton.Configuration.filled()
                config.cornerStyle = .medium
                config.baseBackgroundColor = UIColor { trait in
                    trait.userInterfaceStyle == .dark ? .white : .systemGray2
                }
                button.configuration = config
            } else {
                var config = UIButton.Configuration.filled()
                config.cornerStyle = .medium
                config.baseBackgroundColor = UIColor { trait in
                    trait.userInterfaceStyle == .dark ? .systemGray : .systemGray5
                }
                button.configuration = config
            }
        }
    }

    // 放送局IDの設定
    private func setupStationList() {
        let sldb = StationLocalDB.shared
        stations = sldb.getAllKeys()
        if stations.isEmpty {
            Com.shortMessage("現在位置での放送局データがありません")
            return
        }
        else {
            if viewController?.presenter.currentStationId == nil {
                viewController?.presenter.currentStationId = stations[0]
            }
        }
    }
    
    // 放送局選択UIの作成
    private func setupScrollView() {
        let spacing: CGFloat = 4.0
        let buttonWidth: CGFloat = 112.0
        let buttonHeight: CGFloat = 50.0
        
        let sldb = StationLocalDB.shared
        var itemList = [StationItem]()
        for i in 0..<stations.count {
            if let item = sldb.getData(for: stations[i]) {
                itemList.append(item)
            }
        }
        itemList.sort { $0.id < $1.id }

        // ScrollView を作成
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = true
        stationFrameView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: stationFrameView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: stationFrameView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: stationFrameView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: stationFrameView.trailingAnchor)
        ])

        // コンテンツビュー
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        // ボタンを追加
        var previousButton: ScrollFriendlyButton?
        stationButtons = []
        for i in 0..<itemList.count {
            let item = itemList[i]
            let button = ScrollFriendlyButton(stationId: item.id, imageUrl: item.logoImgUrl)
            // ボタンタップ
            button.onTap = { [weak self] stationId in
                self?.onTapped(stationId: stationId)
            }
            // ボタンのスタイルを設定
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 8
            
            contentView.addSubview(button)
            stationButtons.append(button)
            // オートレイアウトの設定
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: buttonWidth),
                button.heightAnchor.constraint(equalToConstant: buttonHeight),
                button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
            if let prev = previousButton {
                button.leadingAnchor.constraint(equalTo: prev.trailingAnchor, constant: spacing).isActive = true
            } else {
                button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing).isActive = true
            }
            previousButton = button
        }
        
        // 最後のボタンの右端を contentView に固定（これが超重要！）
        if let lastButton = previousButton {
            lastButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing).isActive = true
        }
        
        // 初回のボタンスタイルを設定
        updateStationButtonStyles()
        // 選択しているボタンを見える位置に
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let currentId = self.viewController?.presenter.currentStationId,
               let idx = self.stationButtons.firstIndex(where: { $0.stationId == currentId }) {
                let button = self.stationButtons[idx]
                let buttonCenter = button.center
                let scrollViewWidth = scrollView.bounds.width
                var offsetX = buttonCenter.x - scrollViewWidth / 2
                let maxOffsetX = scrollView.contentSize.width - scrollViewWidth
                offsetX = max(0, min(offsetX, maxOffsetX))
                scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
            }
        }
    }

}
