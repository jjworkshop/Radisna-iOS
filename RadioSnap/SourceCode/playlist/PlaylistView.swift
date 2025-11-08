//
//  PlaylistView.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit

class PlaylistView: CommonView {
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var rightButton1: UIButton!
    @IBOutlet weak var rightButton2: UIButton!
    
    @IBOutlet weak var plFrameView: UIView!
    @IBOutlet weak var plInfoLabel: UILabel!
    @IBOutlet weak var plSlider: UISlider!
    @IBOutlet weak var plPlayTimeLabel: UILabel!
    @IBOutlet weak var plRemainingTimeLabel: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bImage: UIImageView!
    
    @IBOutlet weak var ctrlRewindButton: UIButton!
    @IBOutlet weak var ctrlPlayButton: UIButton!
    @IBOutlet weak var ctrlForwardButton: UIButton!
    
    @IBOutlet weak var plFrameHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var plFrameBottomConstraint: NSLayoutConstraint!
    
    private var lengthToBottom: CGFloat = 0.0
    private var isPlFrameShow: Bool = false
    let ctrlSize = CGSize(width: 36, height: 36)
    
    weak var viewController: PlaylistViewController?

    // 番組情報表示用タイマー
    private var titleIndex = 0
    private var titleTimer: Timer?
    
    // UICollectionVIewに内包するセルのサイズキャッシュ
    var cellSizeCache: CGSize?
    let cellHeight:CGFloat = 88.0
    // フレッシュコントローラー
    let refreshControl = UIRefreshControl()
    
    // レイアウト完了処理
    override func firstlayoutSubviews() {
        // ボタンにアイコン設定
        let size = CGSize(width: 22, height: 22)
        leftButton.setImage(named: AppCom.pdf_circle_down, color: UIColor.label, size: size)
        rightButton1.setImage(named: AppCom.pdf_playlist_delete, color: UIColor.label, size: size)
        rightButton2.setImage(named: AppCom.pdf_sort, color: UIColor.label, size: size)
        ctrlRewindButton.setImage(named: AppCom.pdf_ctl_rewind, color: UIColor.label, size: ctrlSize)
        ctrlForwardButton.setImage(named: AppCom.pdf_ctl_forward, color: UIColor.label, size: ctrlSize)
        changePlayPauseButton(isPlaying: false)
        // 時間表示を等倍フォントにする
        let monospacedFont = UIFont.monospacedDigitSystemFont(ofSize: 14.0, weight: .regular)
        plPlayTimeLabel.font = monospacedFont
        plRemainingTimeLabel.font = monospacedFont
        // テーブルビュー設定
        tableView.register(UINib(nibName: "PlaylistTableViewCell", bundle: nil), forCellReuseIdentifier: "PlaylistCard")
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
        lengthToBottom = plFrameHeightConstraint.constant + Com.safeHightBottom
        plFrameBottomConstraint.constant = lengthToBottom
    }
    
    
    deinit {
        titleTimer?.invalidate()
    }

    // プレイとポーズのボタンを変更
    func changePlayPauseButton(isPlaying: Bool) {
        if isPlaying {
            ctrlPlayButton.setImage(named: AppCom.pdf_ctl_pause, color: UIColor.systemRed, size: ctrlSize)
        }
        else {
            ctrlPlayButton.setImage(named: AppCom.pdf_ctl_play, color: UIColor.systemGreen, size: ctrlSize)
        }
    }
    
    // 再生中の番組情報を表示
    func setInfomation(item: DownloadItem) {
        let sdb = StationDB.shared
        let titles = [
            item.title,
            "\(sdb.getName(stationId: item.stationId)): \(item.bcTime)",
            item.pfm
        ]
        titleIndex = 0
        plInfoLabel.text = titles[titleIndex]
        titleTimer?.invalidate()    // タイマーをリセット
        titleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.titleIndex = (self.titleIndex + 1) % titles.count
            let nextTitle = titles[self.titleIndex]

            UIView.animate(withDuration: 0.9, animations: {
                self.plInfoLabel.alpha = 0.0
            }, completion: { _ in
                self.plInfoLabel.text = nextTitle
                UIView.animate(withDuration: 0.9) {
                    self.plInfoLabel.alpha = 1.0
                }
            })
        }
    }
    
    // [Watch] ウオッチからのリクエストに応答して情報を更新
    func updateInfomation(_ command: String) {
        if let playingItem = AudioPlayerManager.shared.currentItem {
            // 番組情報表示
            setInfomation(item: playingItem)
            // プレイマークを更新するためリロード
            if command == "play" {
                tableView.reloadData()
            }
        }
    }

    // 再生時間（とスライダー）を更新
    func updatePlayingTime(progress: PlProgress) {
        plPlayTimeLabel.text = formatTime(progress.currentTime)
        plRemainingTimeLabel.text = formatTime(progress.duration - progress.currentTime)
        plSlider.maximumValue = Float(progress.duration)
        plSlider.value = Float(progress.currentTime)
    }
    
    // 秒をhh:mm:ss文字列に変換
    private func formatTime(_ seconds: Int) -> String {
        let secs = seconds % 60
        let mins = (seconds / 60) % 60
        let hours = seconds / 3600
        return String(format: "%02d:%02d:%02d", hours, mins, secs)
    }
    
    // ボトムのフレーム down (hide)
    func moveBottomFrameViewDown() {
        if !isPlFrameShow { return }    // 番兵
        plFrameBottomConstraint.constant = lengthToBottom
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
        isPlFrameShow = false
    }
    
    // ボトムのフレーム up (show)
    func moveBottomFrameViewUp() {
        if isPlFrameShow { return }     // 番兵
        plFrameBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
        isPlFrameShow = true
    }
}

