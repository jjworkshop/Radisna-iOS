//
//  TimeTableHelper.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/26.
//

import UIKit
import Alamofire

class TimeTableHelper: NSObject {
    
    let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let stationId: String

    // 番組データ
    private var programsDic: [String: Any]? = nil
    private var today = Com.toYMD(Date())
    var timeTableDate: String {
        return today
    }

    init(stationId: String) {
        self.stationId = stationId
        super.init()
    }

    // 保持しているデータの、ソートした日付（"YYYYMMDD"）リストを取得
    func getDateList() -> [String] {
        if let dic = programsDic {
            let dateIndex = dic.keys.sorted()
            return dateIndex
        }
        return []
    }

    // 日付（必須）と検索文字にmatchしたデータを取得
    func getFindDataAtDate(dataStr: String?, searchStr: String?) -> [[String: Any]] {
        var resultList: [[String: Any]] = []
        guard let dataStr = dataStr else { return resultList }
        if let dic = programsDic, let dateData = dic[dataStr] as? [[String: Any]] {
            if searchStr.isNilOrEmpty {
                return dateData
            }
            // 検索条件有り
            for item in dateData {
                let title = item["title"] as? String ?? ""
                let pfm = item["pfm"] as? String ?? ""
                let tags = item["tags"] as? String ?? ""
                if title.contains(searchStr!) || pfm.contains(searchStr!) || tags.contains(searchStr!) {
                    resultList.append(item)
                }
            }
        }
        // 開始日時でソートする
        return resultList.sorted { ($0["ft"] as? String ?? "") < ($1["ft"] as? String ?? "") }
    }

    // 指定曜日（省略すると全曜日）と検索文字にmatchしたデータを取得
    func getFindDataAtWeek(weekStr: String?, searchStr: String?) -> [[String: Any]] {
        var resultList: [[String: Any]] = []
        if let dic = programsDic {
            for value in dic.values {
                if let filteredData = value as? [[String: Any]] {
                    for item in filteredData {
                        let day = item["day"] as? String ?? ""
                        let title = item["title"] as? String ?? ""
                        let pfm = item["pfm"] as? String ?? ""
                        let tags = item["tags"] as? String ?? ""
                        // Extract the weekday part from the day string
                        let weekday = day.components(separatedBy: "(").dropFirst().first?.components(separatedBy: ")").first ?? ""
                        let weekMatch = weekStr.isNilOrEmpty || weekday == weekStr
                        let searchMatch = searchStr.isNilOrEmpty || title.contains(searchStr!) || pfm.contains(searchStr!) || tags.contains(searchStr!)
                        if weekStr.isNilOrEmpty && searchStr.isNilOrEmpty {
                            resultList.append(item)
                        } else if !weekStr.isNilOrEmpty && searchStr.isNilOrEmpty && weekMatch {
                            resultList.append(item)
                        } else if !weekStr.isNilOrEmpty && !searchStr.isNilOrEmpty && weekMatch && searchMatch {
                            resultList.append(item)
                        } else if weekStr.isNilOrEmpty && !searchStr.isNilOrEmpty && searchMatch {
                            resultList.append(item)
                        }
                    }
                }
            }
        }
        // 開始日時でソートする
        return resultList.sorted { ($0["ft"] as? String ?? "") < ($1["ft"] as? String ?? "") }
    }

    // タイトルを検索し、指定した検索文字と指定した％でマッチした同一番組開始時刻のデータを取得
    func getMatchingData(searchStr: String, startTimeStr: String, accuracy: Int = 80) -> [[String: Any]] {
        guard let dic = programsDic else { return [] }
        // 指定した％でタイトルが一致するキーを収集
        let matchingKeys = dic.filter { (_, value) in
            (value as? [[String: Any]])?.contains(where: { item in
                if let title = item["title"] as? String {
                    return Int(Com.matchPercentage(title, searchStr)) >= accuracy
                }
                return false
            }) ?? false
        }.keys.sorted()
        // ftの時間部分の時間が一致するデータを収集
        var resultList: [[String: Any]] = []
        for key in matchingKeys {
            if let value = dic[key] as? [[String: Any]] {
                for item in value {
                    if let itemFt = item["ft"] as? String, itemFt.suffix(6) == startTimeStr {
                        resultList.append(item)
                    }
                }
            }
        }
        // 開始日時でソートする
        return resultList.sorted { ($0["ft"] as? String ?? "") < ($1["ft"] as? String ?? "") }
    }

    // 放送局の番組データを取得（getTimeTable.py を利用）
    func getTimeTable(callback: @escaping (Bool) -> Void) {
        today = Com.toYMD(Date())
        Com.XLOG("番組データを取得:\(stationId)  today:\(today)")
        // キャッシュがある場合はそれを利用
        if getCache() {
            callback(true)
            return
        }
        let url = "\(AppCom.API_PATH)getTimeTable.py?id=\(stationId)"
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    // JSON全体をパース
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let rinf = json["result"] as? Int, rinf == 0,
                       let timeTableData = json["time_table"] {
                        // timeTableData を JSON 文字列に変換
                        let jsonData = try JSONSerialization.data(withJSONObject: timeTableData, options: [])
                        if let jsonStr = String(data: jsonData, encoding: .utf8) {
                            // パースして辞書に保存
                            self.getProgramsByDate(jsonStr: jsonStr)
                            // キャッシュに保存
                            self.saveCache(programsJson: jsonStr)
                            callback(true)
                            return
                        } else {
                            Com.XLOG("⚠️ JSON文字列への変換に失敗")
                            self.programsDic = nil
                        }
                    } else {
                        Com.XLOG("⚠️ JSON構造が期待と異なる")
                        self.programsDic = nil
                    }
                } catch {
                    Com.XLOG("❌ JSONパースエラー: \(error.localizedDescription)")
                    self.programsDic = nil
                }
            case .failure(_):
                self.programsDic = nil
            }
            callback(false)
        }
    }

    // 放送局の番組データを取得（日付毎）
    private func getProgramsByDate(jsonStr: String) {
        if let data = jsonStr.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.programsDic = jsonObject
            // キーを取得してソートし、配列に変換
            let dateIndex = self.programsDic!.keys.sorted()
            Com.XLOG("DATE_LIST: \(dateIndex.joined(separator: ", "))")
        }
    }

    // キャッシュの読込
    // キャッシュは当日の分のみ有効、それ以外は削除してキャッシュ無しとする
    private func getCache() -> Bool {
        let context = appDelegate.getMoContext()
        if TimeTable.numberOfData(context, stationId: stationId, todayStr: today) != 0 {
            // キャッシュ有り
            Com.XLOG("キャッシュ有り: \(stationId) - \(today)")
            if let item = TimeTable.getItem(context, stationId: stationId, todayStr: today) {
                // パースして辞書に保存
                if let jsonStr = item.jsonStr {
                    getProgramsByDate(jsonStr: jsonStr)
                    return true
                }
            }
        }
        // キャッシュ無し
        Com.XLOG("キャッシュ無し: \(stationId) - \(today)")
        TimeTable.removeStationAll(context, stationId: stationId)
        appDelegate.saveContext()
        return false
    }

    // キャッシュ保存
    private func saveCache(programsJson: String) {
        let context = appDelegate.getMoContext()
        TimeTable.storeData(context, stationId: stationId, todayStr: today, jsonStr: programsJson)
        appDelegate.saveContext()
        Com.XLOG("キャッシュ保存: \(stationId) - \(today)")
    }
}
