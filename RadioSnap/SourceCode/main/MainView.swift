//
//  MainView.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/13.
//

import UIKit

class MainView: CommonView {
    @IBOutlet weak var headerFrame: UIView!
    @IBOutlet weak var licenseUserLabel: UILabel!
    @IBOutlet weak var couponGetLabel: UILabel!
    @IBOutlet weak var couponInfoLabel: UILabel!
    @IBOutlet weak var donationBtn: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bImage: UIImageView!
    @IBOutlet weak var firstInfoLabel: UILabel!
    @IBOutlet weak var plusBtn: FloatingBtnView!
    @IBOutlet weak var playListBtn: FloatingBtnView!
    @IBOutlet weak var recBtn: FloatingBtnView!
    
    weak var viewController: MainViewController?
    
    @IBOutlet weak var headerFrameHeight: NSLayoutConstraint!
    
    // UICollectionVIewに内包するセルのサイズキャッシュ
    var cellSizeCache: CGSize?
    let cellHeight:CGFloat = 108.0
    // フレッシュコントローラー
    let refreshControl = UIRefreshControl()

    
    // レイアウト完了処理
    override func firstlayoutSubviews() {
        // ヘッダーフレームの角丸を確実に設定
        headerFrame.layer.cornerRadius = 8
        headerFrame.layer.masksToBounds = true
        // テーブルビュー設定
        tableView.register(UINib(nibName: "MainTableViewCell", bundle: nil), forCellReuseIdentifier: "MainCard")
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
        // フローティングボタン（＋）と（♪）と（●）
        plusBtn.setImage(name: AppCom.pdf_plus, size: 32)
        playListBtn.setImage(name: AppCom.pdf_playlist, size: 32)
        recBtn.setImage(name: AppCom.pdf_rec, size: 32)
        // クーポン数表示
        updateNumberOfDownloadCoupon()
        // ファーストメッセージを点滅
        UIView.animate(withDuration: 1.5,
                       delay: 3.0,
                       options: .repeat,
                       animations: {
                        self.firstInfoLabel.alpha = 0.0
        }) { (_) in
            self.firstInfoLabel.alpha = 1.0
        }
    }
    
    // 指定のセルを更新
    func updateCell(_ index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    // クーポンのダウンロード数を更新
    func updateNumberOfDownloadCoupon() {
        var reservedCount = 0
        if let context = viewController?.appDelegate.getMoContext() {
            reservedCount = Booking.numberOfReservedData(context)
        }
        let coupon = CouponDB.shared
        couponGetLabel.text = reservedCount == 0
        ? "\(coupon.getCount())" : "\(reservedCount) / \(coupon.getCount())"
    }
    
    // 処理モードによるUIの設定
    func setControlAttributesByMode(_ status: DataLoaderStatus) {
        switch status {
        case .idle:             // アイドル状態
            recBtn.isHidden = true
            recBtn.setImage(name: AppCom.pdf_stop, size: 32)
            viewController?.rightButtonItem2?.isEnabled = true
            viewController?.rightButtonItem3?.isEnabled = true
            viewController?.rightButtonItem2?.tintColor = UIColor.label
            viewController?.rightButtonItem3?.tintColor = UIColor.label
            donationBtn.isUserInteractionEnabled = true
            donationBtn.alpha = 1
            couponInfoLabel.alpha = 1
            if tableView.refreshControl == nil {tableView.refreshControl = refreshControl}
        case .selecting:        // ダウンロードの選択あり
            recBtn.isHidden = false
            recBtn.setImage(name: AppCom.pdf_rec, size: 32, color: UIColor.systemRed)
            viewController?.rightButtonItem2?.isEnabled = false
            viewController?.rightButtonItem3?.isEnabled = true
            viewController?.rightButtonItem2?.tintColor = UIColor.systemGray
            viewController?.rightButtonItem3?.tintColor = UIColor.label
            donationBtn.isUserInteractionEnabled = true
            donationBtn.alpha = 1
            couponInfoLabel.alpha = 1
            if tableView.refreshControl == nil {tableView.refreshControl = refreshControl}
        case .downloading:      // ダウンロード中
            recBtn.isHidden = false
            recBtn.setImage(name: AppCom.pdf_stop, size: 32, color: UIColor.systemIndigo)
            viewController?.rightButtonItem2?.isEnabled = false
            viewController?.rightButtonItem3?.isEnabled = false
            viewController?.rightButtonItem2?.tintColor = UIColor.systemGray
            viewController?.rightButtonItem3?.tintColor = UIColor.systemGray
            donationBtn.isUserInteractionEnabled = false
            donationBtn.alpha = 0.3
            couponInfoLabel.alpha = 0.3
            tableView.refreshControl = nil
            
        }
    }
    
    // ヘッダ下の情報エリアに、ラインセンスユーザー情報の表示
    func showLicenseUser(licenseKey: String?) {
        if let key = licenseKey, !key.isEmpty {
            // ライセンスキーがある場合
            SettingsPresenter.checkLicenseKey(key) { email in
                if let email = email {
                    var user = "unknown user"
                    let pear = email.split(separator: "@")
                    if pear.count == 2, !pear[0].isEmpty {
                        user = String(pear[0])
                    }
                    self.licenseUserLabel.text = "USER: \(user)"
                    self.donationBtn.isHidden = true
                    // クーポン最大
                    let coupon = CouponDB.shared
                    coupon.add(CouponDB.MAX)
                    self.updateNumberOfDownloadCoupon()
                }
            }
        }
    }
    
}
