//
//  MainPresenter.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/13.
//

import UIKit
import RxSwift
import RxCocoa
import CoreData
import RxDataSources
import Alamofire
import CoreLocation

struct SectionOfBookingData {
      var header: String
      var items: [Item]
}
extension SectionOfBookingData: SectionModelType {
    typealias Item = MainPresenter.BookingListItem
    init(original: SectionOfBookingData, items: [Item]) {
        self = original
        self.items = items
    }
}

class MainPresenter: PresenterCommon {
    // 登録できるカードの最大件数
    let maximumNumberOfCards = 300
    
    // データソース
    var dataSource: RxTableViewSectionedReloadDataSource<SectionOfBookingData>? = nil
    
    // リストアイテム
    struct BookingListItem {
        var id: String
        var progress: Int = 0
    }
    
    // UIに対応する Observable
    let isLoading: PublishSubject<Bool> = PublishSubject()                  // リストローディング中
    let list = PublishSubject<[SectionOfBookingData]>()
    let contentCount: PublishSubject<Int> = PublishSubject()                // カードの件数
    let editing: BehaviorRelay<Bool> = BehaviorRelay(value:false)
    let resultGeoLocation: PublishSubject<LatLon> = PublishSubject()          // 位置情報取得結果
    let specialUser: PublishSubject<Bool> = PublishSubject()                // specialユーザー
    let requestReload: PublishSubject<Bool> = PublishSubject()              // カードリロードを依頼
    let appNewsExist: PublishSubject<Bool> = PublishSubject()               // アプリニュースの最新が存在する
    
    // コレクションのアイテム取得（スレッドで）
    func loadItems() {
        isLoading.onNext(true)
        Com.XLOG("番組予約アイテム取得")
        DispatchQueue.global(qos: .default).async {
            let bgContext = self.appDelegate.getMoContext()
            bgContext.perform {
                let allItem = Booking.getAll(bgContext)
                var newList: [BookingListItem] = []
                for uuid in allItem {
                    let listItem = BookingListItem(id: uuid)
                    newList.append(listItem)
                }
                self.list.onNext([SectionOfBookingData(header: "", items: newList)])
                self.contentCount.onNext(newList.count)
                self.isLoading.onNext(false)
            }
        }
    }
    
    // ダウンロード予約の期限が切れているデータの予約を取り消す（status 7 --> 0）
    func cancelExpiredDownload() -> Bool {
        var result = false
        let context = appDelegate.getMoContext()
        let list = Booking.getAllDesignated(context, status: 7) // ダウンロード予約
        if list.count > 0 {
            let now = Date()
            let nowStr = Com.toYMDHMS(now)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
            let weekAgoStr = Com.toYMD(weekAgo) + "050000"
            for uuid in list {
                if let item = Booking.getItem(context, uuid: uuid) {
                    if let endDt = item.endDt, endDt < nowStr {
                        if let startDt = item.startDt, startDt < weekAgoStr {
                            // 1週間より前は期限切れ
                            Com.XLOG("予約取消: \(item.title ?? "no title") \(startDt) - \(endDt)")
                            if Booking.updateStatus(context, uuid: uuid, status: 0) {
                                result = true
                            }
                        }
                    }
                }
            }
        }
        if result { appDelegate.saveContext() }
        return result
    }
    
    // ダウンロード途中で終わっているデータのクリーンアップ（status 8 --> 9）
    func cleanUpDownloading() {
        var result = false
        let context = appDelegate.getMoContext()
        let list = Booking.getAllDesignated(context, status: 8) // ダウンロード中
        if list.count > 0 {
            for uuid in list {
                if let item = Booking.getItem(context, uuid: uuid) {
                    Com.XLOG("DL中断エラー: \(item.title ?? "no title")")
                    if Booking.updateStatus(context, uuid: uuid, status: 9) {
                        result = true
                    }
                }
            }
        }
        if result { appDelegate.saveContext() }
    }
    
    // カードIDからindexを求める
    func findIndexByCardID(uuid: String) -> Int {
        var index = -1
        if dataSource == nil  {return index}    // 番兵
        let spd = dataSource!.sectionModels[0] as SectionOfBookingData
        for (idx, item) in spd.items.enumerated() {
            if (item.id == uuid) {
                index = idx
                break
            }
        }
        // Com.XLOG("ROW=\(index) ID:\(uuid)")
        return index
    }
    
    // データ削除
    // 削除の場合は SectionOfBookingData の item は未だ残っている（自前で削除が必要）
    func removeData(index: Int) -> Bool {
        if (dataSource == nil)  {return false}    // 番兵
        var spd = dataSource!.sectionModels[0] as SectionOfBookingData
        if (spd.items.indices.contains(index)) {
            let uuid = spd.items[index].id
            let context = self.appDelegate.getMoContext()
            Com.XLOG("CardDataを削除: \(uuid)")
            Booking.remove(context, uuid: uuid)
            spd.items.remove(at: index) // 自前で削除が必要
            list.onNext([spd])          // 削除したのでデータ入れ換え
            self.appDelegate.saveContext()
            // リストのカウントを減算
            self.contentCount.onNext(spd.items.count)
            return true
        }
        return false
    }
    
    // データ移動
    // D&D移動の場合は SectionOfCardData の item は既に更新（移動済）されている
    func moveData(srcIndex: Int, desIndex: Int)  -> Bool {
        if (dataSource == nil)  {return false}    // 番兵
        let spd = dataSource!.sectionModels[0] as SectionOfBookingData
        if (spd.items.indices.contains(srcIndex) && spd.items.indices.contains(desIndex)) {
            // seqNo変更により並びを変更
            let ids = spd.items.map{ $0.id }
            rewriteSeq(ids)
            return true
        }
        return false
    }
    
    // seqNo変更により並びを変更
    private func rewriteSeq(_ ids: [String]) {
        let context = self.appDelegate.getMoContext()
        var seqNo = 1
        for uuid in ids.reversed() {
            Com.XLOG("並び替え[\(uuid)]=\(seqNo)")
            _ = Booking.updateSeqNo(context, uuid:uuid, seqNo: seqNo)
            seqNo += 1
        }
        self.appDelegate.saveContext()
    }
    
    // 放送局をセットアップ（AppComに保管）
    func getStationData(location: LatLon, callback: @escaping (String?) -> Void) {
        getRegionCodeAt(lat: location.lat, lon: location.lon) { region in
            if let region = region {
                Com.XLOG("都道府県情報を取得: \(region.name) - \(Thread.isMainThread)")
                callback(region.name)
                if AppCom.region?.pcd != region.pcd {
                    AppCom.region = region
                    self.getStationListAt(region: region) { isOk in
                        if isOk {
                            Com.XLOG("放送局データを取得: region=\(region.pcd) - \(Thread.isMainThread)")
                            // カード更新をリクエスト
                            self.requestReload.onNext(true)
                        }
                    }
                }
            } else {
                callback(nil)
            }
        }
    }
    
    // 現在位置から都道府県情報を取得
    private func getRegionCodeAt(lat: Double, lon: Double, callback: @escaping (Region?) -> Void) {
        let url = "\(AppCom.API_PATH)getRegionCodeAt.py?lat=\(lat)&lon=\(lon)"
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    if let dic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let result = dic["result"] as? Int, result == 0 {
                        let region = Region(
                            pcd: dic["pref_cd"] as? String ?? "",
                            name: dic["pref_name"] as? String ?? "",
                            latLon: LatLon(lat: lat, lon: lon)
                        )
                        callback(region)
                        return
                    }
                } catch {
                    // JSONの内部エラーは先送りに
                }
            case .failure:
                // Requestエラーの場合は先送りに
                break
            }
            callback(nil)
        }
    }

    
    // 放送局データを取得（現在位置から）
    private func getStationListAt(region: Region, callback: @escaping (Bool) -> Void) {
        let url = "\(AppCom.API_PATH)getStationListAt.py?pcd=\(region.pcd)"
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    if let dic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let result = dic["result"] as? Int, result == 0 {
                        AppCom.radikoUrl = dic["radiko_url"] as? String ?? ""
                        if let stations = dic["stations"] as? [[String: Any]] {
                            let sldb = StationLocalDB.shared
                            sldb.removeAll()
                            for station in stations {
                                if let id = station["id"] as? String,
                                   let name = station["name"] as? String,
                                   let logo = station["logo"] as? String,
                                   let href = station["href"] as? String {
                                    let stationItem = StationItem(id: id, name: name, logoImgUrl: logo, url: href)
                                    sldb.storeData(stationItem)
                                }
                            }
                            sldb.storePcd(region.pcd)
                            Com.XLOG("対象放送局： \(sldb.getAllKeys())")
                            callback(true)
                            return
                        }
                    }
                } catch {
                    // JSONの内部エラーは先送りに
                }
            case .failure:
                // Requestエラーの場合は先送りに
                break
            }
            callback(false)
        }
    }
    
    // 全放送局データを取得して保存
    func getAllStationAndSave(callback: @escaping (Int) -> Void) {
        let sdb = StationDB.shared
        var count = sdb.stNumberOfData()
        if count > 0 {
            Com.XLOG("放送局データ取得済")
            callback(count)
            return
        }
        let url = "\(AppCom.API_PATH)getAllStations.py"
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    if let dic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                        for (key, name) in dic {
                            sdb.storeData(stationId: key, name: name)
                            count += 1
                        }
                        callback(count)
                        return
                    }
                } catch {
                    // JSONの内部エラーは先送りに
                }
            case .failure:
                // Requestエラーの場合は先送りに
                break
            }
            callback(0)
        }
    }
    
    // アプリニュースの最終投稿日チェック
    func chackAppNewsDate() {
        appNewsExist.onNext(false)
        let url = "\(AppCom.API_PATH)checkLastUpdateNews.py?id=\(appDelegate.appUUID)"
        AF.request(url).responseData { res in
            switch res.result {
            case .success(let data):
                do {
                    if let dic = try JSONSerialization.jsonObject(with: data) as? Dictionary<String,Any> {
                        var specialFlg = false
                        if let special = dic["special"] as? Int {
                            if special == 1 {
                                // specialユーザー
                                Com.XLOG("👑 スペシャルUSER")
                                specialFlg = true
                            }
                        }
                        self.specialUser.onNext(specialFlg)
                        if let apiResult = dic["result"] as? Int {
                            if apiResult == 0 {
                                // 最終アーティクルの日付取得
                                if let text = dic["text"] as? String {
                                    self.appDelegate.appNewsSiteDate = text      // 保存しておく
                                    let oldText = self.ud.string(forKey: AppCom.USER_DEFKEY_APP_NEWS_TIMESTUMP)
                                    Com.XLOG("アプリニュース記事日付: \(text) old:\(String(describing: oldText))")
                                    self.appNewsExist.onNext(text != oldText)
                                    return
                                }
                            }
                        }
                    }
                    Com.XLOG("checkLastUpdateNews any error")
                }
                catch {
                    Com.XLOG("checkLastUpdateNews get url err from: \(String(describing: String(data: data, encoding: .utf8)))")
                }
            case .failure(let error):
                Com.XLOG("checkLastUpdateNews get url err:\(error.localizedDescription)")
            }
        }
    }
}
