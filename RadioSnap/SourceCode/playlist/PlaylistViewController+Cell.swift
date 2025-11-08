//
//  PlaylistViewController+Cell.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/26.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

extension PlaylistViewController {
    
    func setupCell(_ cell: UITableViewCell, listItem: PlaylistPresenter.PlaylistListItem, row: Int) -> UITableViewCell {
        if let cell = cell as? PlaylistTableViewCell {
            let context = self.appDelegate.getMoContext()
            cell.selectionStyle = .none // セルの選択スタイルをなしにする
            cell.stationLabel.text = ""
            cell.titleLabel.text = ""
            cell.dateTimeLabel.text = ""
            cell.copiedLabel.text = ""
            cell.statusLabel.text = ""
            if let item = Download.getItem(context, uuid: listItem.id) {
                let sdb = StationDB.shared
                cell.stationLabel.text = sdb.getName(stationId: item.stationId ?? "")
                cell.titleLabel.text = item.title
                let dateTime = "\(item.bcDate ?? "") \(item.bcTime ?? "")"
                cell.dateTimeLabel.text = dateTime
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
                // ステータス
                if item.duration > 0 {
                    let progress = Double(item.playbackSec) / Double(item.duration)
                    let percent = Int(progress * 100)
                    cell.statusLabel.text = percent > 0 ? "\(percent)%" : ""
                }
                // 再生中のボタンとステータスカラー
                cell.statusLabel.textColor = UIColor.systemGreen
                cell.titleLabel.textColor = UIColor.label
                var isPlaying = false
                var isPlayed = false
                if let playindUuid = audioPlayer.currentItem?.uuid {
                    isPlaying = playindUuid == item.uuid
                    if isPlaying {
                        cell.statusLabel.textColor = UIColor.systemRed
                        cell.titleLabel.textColor = UIColor.systemRed
                    }
                    else {
                        isPlayed = item.played && item.playbackSec <= 0
                    }
                }
                else {
                    isPlayed = item.played && item.playbackSec <= 0
                }
                if isPlayed {
                    cell.statusLabel.text = "played"
                    cell.statusLabel.textColor = UIColor.systemRed
                }
                cell.playBtnBg.isHidden = isPlaying
                cell.playBtn.isHidden = isPlaying
                // セルのプレイボタンタップ時の処理
                cell.playBtn.rx.tap.asDriver().drive(onNext: { [weak self] _ in
                    self?.cellPlayButtonTaped(index: row, item: item)
                }).disposed(by: cell.disposeBag)
                // セルのメニューボタンタップ時の処理
                cell.menuBtn.rx.tap.asDriver().drive(onNext: { [weak self] _ in
                    self?.cellMenuButtonTaped(index: row, item: item)
                }).disposed(by: cell.disposeBag)
            }
        }
        // テーブルのセパレータを消す
        cell.layoutMargins = .zero
        cell.preservesSuperviewLayoutMargins = false
        return cell
    }
    
}
