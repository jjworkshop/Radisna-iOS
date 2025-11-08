//
//  StationLocalDB.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/15.
//

import UIKit

// 指定地域の送局データデータベース（UserDefaultsに保存）
class StationLocalDB {
    static let shared = StationLocalDB()
    private let prefName = "StationLocalPrefs"
    private let pcdKey = "_PCD_"
    private let userDefaults = UserDefaults.standard

    private init() {}

    // すべてのデータを削除
    func removeAll() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(prefName) {
            userDefaults.removeObject(forKey: key)
        }
    }

    // 都道府県コードを保存
    func storePcd(_ pcd: String) {
        userDefaults.set(pcd, forKey: prefName + pcdKey)
    }

    // 都道府県コードを取得
    func getPcd() -> String? {
        return userDefaults.string(forKey: prefName + pcdKey)
    }

    // 放送局ローカルデータを保存
    func storeData(_ item: StationItem) {
        let json: [String: Any] = [
            "name": item.name,
            "logoImgUrl": item.logoImgUrl,
            "url": item.url
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) {
            userDefaults.set(jsonData, forKey: prefName + "_" + item.id)
        }
    }

    // 放送局ローカルデータを取得
    func getData(for id: String) -> StationItem? {
        guard let jsonData = userDefaults.data(forKey: prefName + "_" + id),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
              let name = json["name"] as? String,
              let logoImgUrl = json["logoImgUrl"] as? String,
              let url = json["url"] as? String else {
            return nil
        }
        return StationItem(id: id, name: name, logoImgUrl: logoImgUrl, url: url)
    }

    // 全ての放送局コードを取得
    func getAllKeys() -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let prefix = prefName + "_"
        let stationKeys = allKeys
            .filter { $0.hasPrefix(prefix) && !$0.contains(pcdKey) }
            .map { String($0.dropFirst(prefix.count)) }
        return Array(stationKeys)
    }
}

