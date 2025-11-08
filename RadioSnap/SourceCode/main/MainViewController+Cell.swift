//
//  MainViewController+Cell.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

// テーブルのセル設定部分のみ
extension MainViewController {
    
    func setupCell(_ cell: UITableViewCell, listItem: MainPresenter.BookingListItem, row: Int) -> UITableViewCell {
        if let cell = cell as? MainTableViewCell {
            let context = self.appDelegate.getMoContext()
            cell.selectionStyle = .none // セルの選択スタイルをなしにする
            cell.stationLabel.text = ""
            cell.titleLabel.text = ""
            cell.dateTimeLabel.text = ""
            cell.pfmLabel.text = ""
            cell.downloadBtnBg.isHidden = false
            cell.downloadBtn.isHidden = false
            cell.detailBtn.isHidden = false
            cell.loadingProgress.isHidden = true
            cell.downloadBtn.tintColor = UIColor.white
            cell.detailBtn.tintColor = UIColor.white
            cell.downloadBtn.isEnabled = true
            cell.detailBtn.isEnabled = true
            if let item = Booking.getItem(context, uuid: listItem.id) {
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
                // 文字情報
                let sdb = StationDB.shared
                cell.stationLabel.text = sdb.getName(stationId: item.stationId ?? "")
                cell.titleLabel.text = item.title
                let dateTime = "\(item.bcDate ?? "") \(item.bcTime ?? "")"
                cell.dateTimeLabel.text = dateTime
                cell.pfmLabel.text = item.pfm
                // ステータスによるカードカラー
                let cardBgColor: UIColor
                switch item.status {
                case 0, 1, 7:      // 0=予約, 1=ダウンロード済、7=ダウンロード予約（iOSのみ）
                    cardBgColor = UIColor.asset(named: AppCom.rgb_card)
                case 2, 8:      // 2=ダウンロードキャンセル, 8=ダウンロード中
                    cardBgColor = UIColor.asset(named: AppCom.rgb_card_busy)
                default:        // 9=ダウンロードエラー
                    cardBgColor = UIColor.asset(named: AppCom.rgb_card_err)
                }
                cell.cardFrame.backgroundColor = cardBgColor
                // アイコン変更
                cell.status = Int(item.status)
                switch item.status {
                case 0, 1:
                    // Downloadテーブルにデータが有り、かつファイルが存在しているかどうかで判定
                    let isDataAvailable = Download.exist(context, stationId: item.stationId ?? "", startDt: item.startDt ?? "") != nil
                    let saveFile = downloader.makeDlFileName(stationId: item.stationId ?? "", startDt: item.startDt ?? "")
                    if isDataAvailable && downloader.isFileExists(saveFile) {
                        // ダウンロード済み
                        cell.downloadBtnBg.isHidden = true
                        cell.downloadBtn.isHidden = true
                    }
                case 7:
                    // ダウンロード予約
                    cell.downloadBtn.tintColor = UIColor.systemGreen
                case 8:
                    // ダウンロード中
                    cell.downloadBtnBg.isHidden = true
                    cell.downloadBtn.isHidden = true
                    cell.detailBtn.isHidden = true
                case 9:
                    // ダウンロードエラー
                    cell.downloadBtn.tintColor = UIColor.systemRed
                default:
                    break
                }
                if downloader.satus.value == DataLoaderStatus.downloading {
                    // ダウンロード中は他のカードのボタンも無効
                    cell.downloadBtnBg.isHidden = true
                    cell.downloadBtn.isHidden = true
                    cell.detailBtn.isHidden = true
                }
                // 番組時間によるカラー変更
                let date = Date()
                var dateStr = Com.toYMDHMS(date)
                if item.endDt! >= dateStr {
                    // 未来
                    cell.downloadBtn.isHidden = true
                    cell.downloadBtnBg.isHidden = true
                    cell.dateTimeLabel.textColor = UIColor.asset(named: AppCom.rgb_text_black)
                } else {
                    // 過去データ
                    let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: date)!
                    dateStr = Com.toYMD(weekAgo) + "050000"
                    if item.startDt! < dateStr {
                        // １周間より前
                        cell.downloadBtn.isHidden = true
                        cell.downloadBtnBg.isHidden = true
                        cell.dateTimeLabel.textColor = UIColor.asset(named: AppCom.rgb_text_disable)
                    } else {
                        // １周間以内
                        if cell.downloadBtn.isHidden {
                            // ダウンロード済み
                            cell.dateTimeLabel.textColor = UIColor.systemGreen.withAlphaComponent(0.5)
                        } else {
                            cell.dateTimeLabel.textColor = UIColor.systemMint
                        }
                    }
                }
                
                // ダウンロード中の設定
                // ダウンロード（キャンセル）の完了でセルをリフレッシュするので、以下の設定を戻す処理は不要
                // リフレッシュ時にDB内容によりUIは更新される
                if downloader.satus.value == .downloading {
                    if item.status == 8 {
                        // ダウンロード中
                        cell.downloadBtn.isHidden = true
                        cell.downloadBtnBg.isHidden = true
                        cell.detailBtn.isHidden = true
                        cell.loadingProgress.isHidden = false
                    }
                    else {
                        cell.downloadBtn.isEnabled = false
                        cell.downloadBtn.tintColor = UIColor.systemGray
                        cell.detailBtn.isEnabled = false
                        cell.detailBtn.tintColor = UIColor.systemGray
                    }
                }
                
                // セルのダウンロードボタンタップ時の処理
                cell.downloadBtn.rx.tap.asDriver().drive(onNext: { [weak self] _ in
                    self?.cellDownloadButtonTaped(index: row, item: item)
                }).disposed(by: cell.disposeBag)
                // セルの詳細ボタンタップ時の処理
                cell.detailBtn.rx.tap.asDriver().drive(onNext: { [weak self] _ in
                    self?.cellDetailButtonTaped(index: row, item: item)
                }).disposed(by: cell.disposeBag)
            }
        }
        // テーブルのセパレータを消す
        cell.layoutMargins = .zero
        cell.preservesSuperviewLayoutMargins = false
        return cell
    }
    
}
