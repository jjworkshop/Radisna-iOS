//
//  PlaylistMenuView.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/02.
//

import UIKit
import RxWebKit

class PlaylistMenuView: CommonView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var closeBtn: UIButton!
    
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var stationLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var pfmLabel: UILabel!
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var shareBtn: UIButton!

    let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    lazy var imageDownloader = appDelegate.getImageDownloader()
    
    // レイアウト完了処理
    override func firstlayoutSubviews() {
        // ボタンにアイコン設定
        let size = CGSize(width: 22, height: 22)
        closeBtn.setImage(named: AppCom.pdf_close, color: UIColor.label, size: size)
    }
    
    // 画面初期セットアップ
    func setup(_ item: DownloadItem) {
        // ダウンロードデータ情報
        titleLabel.text = item.title
        let sdb = StationDB.shared
        stationLabel.text = sdb.getName(stationId: item.stationId)
        let dateTime = "\(item.bcDate) \(item.bcTime)"
        dateTimeLabel.text = dateTime
        pfmLabel.text = item.pfm
        // バナーイメージ
        if !item.imgUrl.isEmpty, let imageUrl = URL(string: item.imgUrl) {
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
    }
}
