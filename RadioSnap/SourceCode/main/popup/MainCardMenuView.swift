//
//  MainCardMenuView.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/02.
//

import UIKit
import RxWebKit

class MainCardMenuView: CommonView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var closeBtn: UIButton!
    
    @IBOutlet weak var loadingLabel: LoadingLabel!
    
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var pageLabel: UILabel!
    @IBOutlet weak var stationLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var pfmLabel: UILabel!
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var updateBtn: UIButton!
    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var nextBtn: UIButton!
    
    let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    lazy var imageDownloader = appDelegate.getImageDownloader()
    
    // レイアウト完了処理
    override func firstlayoutSubviews() {
        // ボタンにアイコン設定
        let size = CGSize(width: 22, height: 22)
        closeBtn.setImage(named: AppCom.pdf_close, color: UIColor.label, size: size)
        let sizeL = CGSize(width: 28, height: 28)
        backBtn.setImage(named: AppCom.pdf_arrow_left, color: UIColor.label, size: sizeL)
        nextBtn.setImage(named: AppCom.pdf_arrow_right, color: UIColor.label, size: sizeL)
        // 最初にボタンを非表示
        nextBtn.isHidden = true
        backBtn.isHidden = true
        updateBtn.isHidden = true
        deleteBtn.isHidden = true
    }
    
    // 番組情報を画面に設定
    func setDetailsInfo(bookingItem: BookingItem) {
        titleLabel.text = bookingItem.title
        let sdb = StationDB.shared
        stationLabel.text = sdb.getName(stationId: bookingItem.stationId)
        let dateTime = "\(bookingItem.bcDate) \(bookingItem.bcTime)"
        dateTimeLabel.text = dateTime
        pfmLabel.text = bookingItem.pfm
        // バナーイメージ
        let urlString = bookingItem.imgUrl
        if !urlString.isEmpty, let imageUrl = URL(string: urlString) {
            bannerImageView.af_setImage_ex(with: imageUrl,
                                           imageDownloader: imageDownloader,
                                           placeholderImage: UIImage(named: "img_loading"),
                                           imageTransition: .crossDissolve(0.8),
                                           progress: nil, completion: { (res) -> Void in
                if res.error != nil {
                    self.bannerImageView.image = UIImage(named: "img_noimage")
                }
            })
        }
        else {
            bannerImageView.image = UIImage(named: "img_na")
        }
        // 番組開始日時により dateTimeLabel のテキストカラー変更
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let dateStr = formatter.string(from: now)
        if bookingItem.endDt >= dateStr {
            // 未来
            dateTimeLabel.textColor = UIColor.label
        } else {
            // 過去データ
            if let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) {
                let weekAgoStr = DateFormatter()
                weekAgoStr.dateFormat = "yyyyMMdd"
                let weekAgoDateStr = weekAgoStr.string(from: weekAgo) + "050000"
                if bookingItem.startDt < weekAgoDateStr {
                    // １周間より前
                    dateTimeLabel.textColor = UIColor.systemGray
                } else {
                    // １周間以内
                    dateTimeLabel.textColor = UIColor.systemMint
                }
            }
        }
    }
}


