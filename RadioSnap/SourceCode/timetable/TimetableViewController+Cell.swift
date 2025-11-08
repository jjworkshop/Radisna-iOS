//
//  TimetableViewController+Cell.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/26.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

extension TimetableViewController {
    
    func setupCell(_ cell: UITableViewCell, listItem: TimetablePresenter.TimetableListItem, row: Int) -> UITableViewCell {
        if let cell = cell as? TimetableTableViewCell {
            cell.selectionStyle = .none // セルの選択スタイルをなしにする
            cell.titleLabel.text = ""
            cell.dateTimeLabel.text = ""
            if let program = presenter.getProgram(index: listItem.id.toInt()) {
                if let item = presenter.makeProgramItem(from: program) {
                    cell.titleLabel.text = item.title
                    let dateTime = "\(item.bcDate) \(item.bcTime)"
                    cell.dateTimeLabel.text = dateTime
                    // バナーイメージ
                    if let urlString = item.imgUrl, !urlString.isEmpty, let imageUrl = URL(string: urlString) {
                        cell.bannerImageView.af_setImage_ex(with: imageUrl,
                                                 imageDownloader: imageDownloader,
                                                 placeholderImage: UIImage(named: "img_loading"),
                                                 imageTransition: .crossDissolve(0.8),
                                                 progress: nil, completion: { (res) -> Void in
                            if res.error != nil {
                                cell.bannerImageView.image = UIImage(named: "img_noimage")
                            }
                        })
                    }
                    else {
                        cell.bannerImageView.image = UIImage(named: "img_na")
                    }
                    // ボタンの状態
                    let stationId = presenter.currentStationId ?? ""
                    if presenter.existBookingItem(stationId: stationId, startDt: item.startDt) {
                        cell.addBtn.tintColor = .systemGreen
                    }
                    else {
                        cell.addBtn.tintColor = .systemGray
                    }
                    // セルのプラスボタンタップ時の処理
                    cell.addBtn.rx.tap.asDriver().drive(onNext: { [weak self] _ in
                        self?.cellAddButtonTaped(index: row, item: item)
                    }).disposed(by: cell.disposeBag)
                    // イメージタップ時の処理
                    cell.bannerImageView.isUserInteractionEnabled = true
                    cell.bannerImageView.rx.tapGesture()
                        .when(.recognized)
                        .asDriver(onErrorDriveWith: .empty())
                        .drive(onNext: { [weak self] _ in
                            self?.cellBannerImageTaped(index: row, item: item)
                        })
                        .disposed(by: cell.disposeBag)
                }
            }
            
        }
        // テーブルのセパレータを消す
        cell.layoutMargins = .zero
        cell.preservesSuperviewLayoutMargins = false
        return cell
    }
    
}
