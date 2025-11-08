//
//  TimetableTableViewCell.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit
import RxSwift

class TimetableTableViewCell: UITableViewCell {
    
    @IBOutlet weak var cardFrame: UIView!
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var addBtn: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!

    
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
        let addBtnImg = UIImage(named: AppCom.pdf_plus_circle)?
            .resize(CGSize(width: 40, height: 40)).withRenderingMode(.alwaysTemplate)
        addBtn.setImage(addBtnImg, for: .normal)
    }
}
