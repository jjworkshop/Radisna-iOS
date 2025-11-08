//
//  PlaylistTableViewCell.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit
import RxSwift

class PlaylistTableViewCell: UITableViewCell {
    
    @IBOutlet weak var cardFrame: UIView!
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var playBtnBg: UIView!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var menuBtn: UIButton!
    @IBOutlet weak var stationLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var copiedLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    var disposeBag = DisposeBag()
    
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
        let playBtnImg = UIImage(named: AppCom.pdf_play_circle)?
            .resize(CGSize(width: 36, height: 36)).withRenderingMode(.alwaysTemplate)
        playBtn.setImage(playBtnImg, for: .normal)
        let menuBtnImg = UIImage(named: AppCom.pdf_menu)?
            .resize(CGSize(width: 32, height: 32))
            .withTintColor(.systemMint)
            .withRenderingMode(.alwaysOriginal)
        menuBtn.setImage(menuBtnImg, for: .normal)
        let menuBtnImgTpl = UIImage(named: AppCom.pdf_menu)?
            .resize(CGSize(width: 32, height: 32))
            .withTintColor(.systemGray)
            .withRenderingMode(.alwaysOriginal)
        menuBtn.setImage(menuBtnImgTpl, for: .highlighted)

    }
}
