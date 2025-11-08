//
//  TimetablePresenter.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit
import RxSwift
import RxCocoa
import CoreData
import RxDataSources

struct SectionOfTimetableData {
      var header: String
      var items: [Item]
}
extension SectionOfTimetableData: SectionModelType {
    typealias Item = TimetablePresenter.TimetableListItem
    init(original: SectionOfTimetableData, items: [Item]) {
        self = original
        self.items = items
    }
}

struct ProgramItem {
    let startDt: String
    let endDt: String
    let title: String
    let bcDate: String
    let bcTime: String
    let url: String?
    let pfm: String?
    let imgUrl: String?
}

class TimetablePresenter: PresenterCommon {
    // データソース
    var dataSource: RxTableViewSectionedReloadDataSource<SectionOfTimetableData>? = nil
    // 取得した番組で表示対象のデータのリスト
    private var matchList: [[String: Any]]? = nil
    
    // リストアイテム
    struct TimetableListItem {
        var id: String
    }
    
    // UIに対応する Observable
    let isLoading: PublishSubject<Bool> = PublishSubject()          // リストローディング中
    let list = PublishSubject<[SectionOfTimetableData]>()
    let contentCount: PublishSubject<Int> = PublishSubject()        // カードの件数
    let addBookingCount: PublishSubject<Int> = PublishSubject()     // 追加する番組のカウント
    let searchFilterCheck: PublishSubject<Bool> = PublishSubject()  // 検索フィルターチェック
    let changedStationId: PublishSubject<Bool> = PublishSubject()   // 放送局ID変更
    let searchText: PublishSubject<String> = PublishSubject()       // 検索文字列
    let weekText: PublishSubject<String> = PublishSubject()         // 曜日文字列（"","日","月" …）
    
    // 現在の選択中の放送局ID
    private let currentStationIdKey = "currentStationId"
    var currentStationId: String? {
        get {
            return UserDefaults.standard.string(forKey: currentStationIdKey)
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: currentStationIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: currentStationIdKey)
            }
        }
    }
    
    // 番組一覧で現在選択中の曜日
    private let currentWeekStrKey = "currentWeekStr"
    var currentWeekStr: String? {
        get {
            return UserDefaults.standard.string(forKey: currentWeekStrKey)
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: currentWeekStrKey)
            } else {
                UserDefaults.standard.removeObject(forKey: currentWeekStrKey)
            }
        }
    }
    
    // 番組一覧で現在選択中の検索文字列
    private let currentSearchStrKey = "currentSearchStr"
    var currentSearchStr: String? {
        get {
            return UserDefaults.standard.string(forKey: currentSearchStrKey)
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: currentSearchStrKey)
            } else {
                UserDefaults.standard.removeObject(forKey: currentSearchStrKey)
            }
        }
    }
    
    // コレクションのアイテム取得（スレッドで）
    private var oldStationId: String? = nil
    private var oldWeekStr: String? = nil
    private var oldSearchStr: String? = nil
    func loadItems(stationId: String?, weekStr: String?, searchStr: String?,
                   forced: Bool, callback: @escaping (Bool) -> Void) {
        // 同一の検索条件はスキップ
        if oldStationId == stationId && oldWeekStr == weekStr && oldSearchStr == searchStr && !forced {
            Com.XLOG("番組データロード:スキップ")
            callback(true)
            return
        }
        oldStationId = stationId
        oldWeekStr = weekStr
        oldSearchStr = searchStr
        if let stationId = stationId {
            Com.XLOG("番組データロード: S=\(stationId) T=\(searchStr ?? "") W=\(weekStr ?? "")")
            let ttHelper = TimeTableHelper(stationId: stationId)
            isLoading.onNext(true)
            ttHelper.getTimeTable { _ in
                // 対象データ抽出
                self.matchList = ttHelper.getFindDataAtWeek(weekStr: weekStr, searchStr: searchStr)
                // リストにはインデックスだけ
                let list = (0..<(self.matchList?.count ?? 0)).map { "\($0)" }
                var newList: [TimetableListItem] = []
                for index in list {
                    let listItem = TimetableListItem(id: index)
                    newList.append(listItem)
                }
                self.list.onNext([SectionOfTimetableData(header: "", items: newList)])
                self.contentCount.onNext(list.count)
                self.isLoading.onNext(false)
                callback(true)
            }
        } else {
            Com.XLOG("対象データ無し（放送局未指定）")
            contentCount.onNext(0)
            callback(false)
        }
    }

    // 指定indexの番組データを取り出し
    func getProgram(index: Int) -> [String: Any]? {
        if let matchList = matchList, matchList.indices.contains(index) {
            return matchList[index]
        }
        return nil
    }
    
    // 番組データをパース
    func makeProgramItem(from data: [String: Any]) -> ProgramItem? {
        guard
            let startDt = data["ft"] as? String,
            let endDt = data["to"] as? String,
            let title = data["title"] as? String,
            let bcDate = data["day"] as? String,
            let bcTime = data["from_to"] as? String
        else {
            return nil
        }
        let url = data["url"] as? String ?? ""
        let pfm = data["pfm"] as? String ?? ""
        let imgUrl = data["img"] as? String ?? ""
        return ProgramItem(
            startDt: startDt,
            endDt: endDt,
            title: title,
            bcDate: bcDate,
            bcTime: bcTime,
            url: url,
            pfm: pfm,
            imgUrl: imgUrl
        )
    }
    
    // 追加する番組リスト操作
    var bookingItemList: [BookingItem] = []
    var numberOfBookingItem: Int {
        return bookingItemList.count
    }
    func addBookingItem(_ item: BookingItem) {
        bookingItemList.append(item)
        addBookingCount.onNext(bookingItemList.count)
    }
    func removeBookingItem(stationId: String, startDt: String) {
        bookingItemList.removeAll { $0.stationId == stationId && $0.startDt == startDt }
        addBookingCount.onNext(bookingItemList.count)
    }
    func removeAllBookingItem() {
        bookingItemList.removeAll()
        addBookingCount.onNext(bookingItemList.count)
    }
    func existBookingItem(stationId: String, startDt: String) -> Bool {
        return bookingItemList.contains { $0.stationId == stationId && $0.startDt == startDt }
    }

}
