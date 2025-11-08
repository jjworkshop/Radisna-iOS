//
//  MainTableViewCell.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/13.
//

import UIKit
import RxSwift

class MainTableViewCell: UITableViewCell {
    
    @IBOutlet weak var cardFrame: UIView!
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var downloadBtnBg: UIView!
    @IBOutlet weak var downloadBtn: UIButton!
    @IBOutlet weak var stationLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var pfmLabel: UILabel!
    @IBOutlet weak var detailBtn: UIButton!
    @IBOutlet weak var loadingProgress: UIProgressView!
    
    
    var disposeBag = DisposeBag()
    var status: Int = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        // カードフレームの角丸を確実に設定
        cardFrame.layer.cornerRadius = 8
        cardFrame.layer.masksToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.disposeBag = DisposeBag()  // ここで毎回生成
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // ボタンアイコン設定
        changeDownloadBtnImage(status)
        let detailBtnImg = UIImage(named: AppCom.pdf_detail)?
            .resize(CGSize(width: 36, height: 36))
            .withTintColor(.systemMint)
            .withRenderingMode(.alwaysOriginal)
        detailBtn.setImage(detailBtnImg, for: .normal)
        let detailBtnImgTpd = UIImage(named: AppCom.pdf_detail)?
            .resize(CGSize(width: 36, height: 36))
            .withTintColor(.systemGray)
            .withRenderingMode(.alwaysOriginal)
        detailBtn.setImage(detailBtnImgTpd, for: .highlighted)
    }
    
    // ダウンロードボタンのアイコンを変更
    func changeDownloadBtnImage(_ status: Int) {
        if status == 7 {
            // ダウンロード予約
            let downloadBtnImg = UIImage(named: AppCom.pdf_check)?
                .resize(CGSize(width: 30, height: 30)).withRenderingMode(.alwaysTemplate)
            downloadBtn.setImage(downloadBtnImg, for: .normal)
        }
        else {
            // それ以外
            let downloadBtnImg = UIImage(named: AppCom.pdf_download)?
                .resize(CGSize(width: 32, height: 32)).withRenderingMode(.alwaysTemplate)
            downloadBtn.setImage(downloadBtnImg, for: .normal)
        }
    }
}
