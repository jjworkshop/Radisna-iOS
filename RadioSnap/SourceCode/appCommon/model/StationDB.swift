//
//  StationDB.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/15.
//

import UIKit

// 全放送局データデータベース（UserDefaultsに保存）
class StationDB {
    static let shared = StationDB()
    private let prefName = "StationPrefs"
    private let userDefaults = UserDefaults.standard

    private init() {}

    // データ件数を取得
    func stNumberOfData() -> Int {
        let keys = userDefaults.dictionaryRepresentation().keys
        return keys.filter { $0.hasPrefix(prefName) }.count
    }

    // すべてのデータを削除
    func removeAll() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(prefName) {
            userDefaults.removeObject(forKey: key)
        }
    }

    // ステーションデータを保存
    func storeData(stationId: String, name: String) {
        userDefaults.set(name, forKey: prefName + "_" + stationId)
    }

    // ステーションデータを取得
    func getName(stationId: String) -> String {
        let name = userDefaults.string(forKey: prefName + "_" + stationId)
        return name ?? stationId
    }
}
