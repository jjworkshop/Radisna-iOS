//
//  SettingsPresenter.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit
import RxSwift
import RxCocoa

class SettingsPresenter: PresenterCommon {
        
    // キャッシュクリア
    func cleatCache() {
        // 番組データと視聴履歴のクリア
        let context = appDelegate.getMoContext()
        TimeTable.removeAll(context)
        let list = Download.getAll(context, sortPattern: 0)
        for uuid in list {
            _ = Download.updatePlaybackSecs(context, uuid: uuid, playbackSec: 0, duration: 0)
            _ = Download.updateMediaStorePlayed(context, uuid: uuid, played: false)
        }
        self.appDelegate.saveContext()
        // イメージキャッシュのクリア
        appDelegate.removeImageCache()
        // アプリニュースの最終記事日時も削除
        ud.removeObject(forKey: AppCom.USER_DEFKEY_APP_NEWS_TIMESTUMP)
        appDelegate.appNewsSiteDate = ""
        // 問合せの確認のクリア
        let udKeys = ["showFirstConfirmDialog",     // 初期のインフォメーション
                      "showNotEnoughCouponDialog",  // クーポン不足で広告視聴
                      "showStartDownloadDialog",    // ダウンロード開始
                      "showAdConfirmDialog"         // 広告視聴開始
                      ]
        for key in udKeys {
            ud.removeObject(forKey: key)
        }
        // ダウンロードデータが０件の場合、/Documents/audio 内の全てのファイルを削除する
        if Download.numberOfData(context) == 0 {
            Com.XLOG("ダウンロード０件: 不要番組ファイル削除開始！")
            removeAllAudioFiles()
        }
        
        // 設定クリア（DEGUB用）
        /*
        let stKeys = [AppCom.USER_DEFKEY_DOWNLOAD_FIRST,
                      AppCom.USER_DEFKEY_KEEP_SCREEN,
                      AppCom.USER_DEFKEY_LOG_MODE,
                      AppCom.USER_DEFKEY_APPEARANCE_MODE
                      ]
        for key in stKeys {
            ud.removeObject(forKey: key)
        }
        */
    }
        
    // ストアで評価
    // ここは自分のアプリのAppleIDに変更する必要がある
    func showStoreRting() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id6747058371?action=write-review") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            }
            else {
                Com.XLOG("Can not open review of AppStore")
                Com.shortMessage("Can not open review of AppStore")
            }
        }
    }
    
    // サポートサイト表示
    func showSupportSite() {
        let urlStr = "https://jjworkshop.com/app/manual/radiosnap_x_ios.html?\(htmlParameter())"
        AppCom.showSite(url: urlStr)
    }
    
    // アプリの最新ニュースページ表示
    func showAppNewsSite() {
        let urlStr = "https://jjworkshop.com/blog/archives/radiosnap_x/?\(htmlParameter())"
        AppCom.showSite(url: urlStr)
        ud.set(appDelegate.appNewsSiteDate, forKey: AppCom.USER_DEFKEY_APP_NEWS_TIMESTUMP)
    }
    
    // HTMLにパラメタを付与する文字列を作成
    private func htmlParameter() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHH"
        return formatter.string(from: Date())
    }

    // 番組ファイルを全て削除（Download件数が０の場合に処理：不要ファイルの削除）
    private func removeAllAudioFiles() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let audioDirURL = documentsURL.appendingPathComponent("audio")
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: audioDirURL, includingPropertiesForKeys: nil)
            if fileURLs.isEmpty {
                Com.XLOG("audioディレクトリは空")
            } else {
                for url in fileURLs {
                    Com.XLOG("削除ファイル: \(url.lastPathComponent)")
                    try? fileManager.removeItem(at: url)
                }
            }
        } catch {
            Com.XLOG("audioディレクトリの操作エラー: \(error)")
        }
    }

}

// MARK: - バックアップ処理系

extension SettingsPresenter {
    // 全カードデータをJSONで保存（スレッド処理）
    // ちなみに、documentDirectoryのファイルはiCloudのバックアップ対象
    func saveAllCardDataToJson(callback: @escaping () -> Void) {
        DispatchQueue.global(qos: .default).async {
            let bgContext = self.appDelegate.getMoContext()
            bgContext.perform {
                // JSON作成
                var items: [BookingItem] = []
                let ids = Booking.getAll(bgContext)
                for id in ids {
                    if let data = Booking.getItem(bgContext, uuid: id),
                       let item = BookingItem.from (booking: data) {
                        items.append(item)
                    }
                }
                for item in items {
                    item.status = 0
                }
                items = items.sorted { $0.seqNo < $1.seqNo }
                let encoder = JSONEncoder()
                if let jsonData = try? encoder.encode(items),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        // ファイル書き込み（メインスレッド）
                        let date = Date()
                        let fileName = "RadioSnap_\(Com.getYYYYMMDD_S(date).replacingOccurrences(of: "/", with: "")).json"
                        Com.XLOG("saveFile: \(fileName)")
                        if let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                            let fileURL = dirURL.appendingPathComponent(fileName)
                            do {
                                try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
                                callback()
                            }
                            catch {
                                Com.XLOG("save error: \(error)")
                            }
                        }
                        else {
                            Com.XLOG("save pass error!!")
                        }
                    }
                }
            }
        }
    }
    
    // ドキュメントファイル（JSONデータ）からカードデータ復元
    func restore(jsonStr: String, callback: @escaping (_ count: Int, _ err: Int) -> Void) {
        DispatchQueue.global().async {
            let bgContext = self.appDelegate.getMoContext()
            bgContext.perform {
                var items: [BookingItem]? = nil
                let decoder = JSONDecoder()
                do {
                    if let data = jsonStr.data(using: .utf8) {
                        items = try decoder.decode([BookingItem].self, from: data)
                    }
                } catch {
                    Com.XLOG("json err: \(error)")
                }
                var count = 0
                var errorCount = 0
                if let items = items, !items.isEmpty {
                    for item in items {
                        // IDが無い場合はスキップ
                        if item.uuid.isEmpty {
                            errorCount += 1
                            continue
                        }
                        let result = Booking.storeData(bgContext, item: item)
                        try? bgContext.save()
                        if count == 0 {
                            // １件でも書き込めたら元データを削除して最初のデータを再度書き込み
                            if let uuid = result {
                                Booking.removeAll(bgContext)
                                if !Booking.exist(bgContext, uuid: uuid) {
                                    // 一応存在チェックしていから処理
                                    //（対策はしたけど、以前の処理方法でコアデータのキャッシュ問題があったので残している）
                                    _ = Booking.storeData(bgContext, item: item)
                                }
                                count += 1
                            }
                            else {
                                errorCount += 1
                            }
                        }
                        else {
                            if let _ = result {
                                count += 1
                            }
                            else {
                                errorCount += 1
                            }
                        }
                    }
                    if count > 0 {
                        self.appDelegate.saveContext()
                    }
                }
                DispatchQueue.main.async {
                    callback(count, errorCount)
                }
            }
        }
    }
}

import Alamofire

extension SettingsPresenter {
    
    // ライセンスキーをチェック
    static func checkLicenseKey(_ licenseKey: String, callback: @escaping (_ email: String?) -> Void) {
        let url = "\(AppCom.API_PATH)checkLicenseKey.py?id=\(licenseKey)"
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    if let dic = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let email = dic["email"] as? String,
                       !email.isEmpty {
                        callback(email)
                        return
                    }
                } catch {
                    // JSONパースエラー
                }
            case .failure:
                // 通信エラー
                break
            }
            callback(nil)
        }
    }
}
