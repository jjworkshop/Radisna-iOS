//
//  CouponDB.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/19.
//

import UIKit

// クーポンデータデータベース（UserDefaultsに保存）
class CouponDB {
    static let shared = CouponDB()
    private let prefName = "CouponPrefs"
    private let userDefaults = UserDefaults.standard
    
    static let DEFAULT_COUNT = 30       // 初期のダウンロードクーポン数
    static let DAILY_COUPON = 2         // １日に１度追加するクーポンの数
    static let MAX = 99                 // クーポンの最大数
    
    private init() {
        let countKey = prefName + "_count"
        if userDefaults.object(forKey: countKey) == nil {
            userDefaults.set(Self.DEFAULT_COUNT - Self.DAILY_COUPON, forKey: countKey)
        }
    }
    
    // Couponの数を取得
    func getCount() -> Int {
        return userDefaults.integer(forKey: prefName + "_count")
    }
    
    // Couponの数を増減
    func add(_ additional: Int) {
        let count = min(getCount() + additional, CouponDB.MAX)
        userDefaults.set(count, forKey: prefName + "_count")
    }
    
    // １日１回だけクーポンを追加（MainViewController:viewWillAppearで呼び出し）
    func addOncePerDay(_ additional: Int = CouponDB.DAILY_COUPON) {
        let lastDateKey = prefName + "_lastAddedDate"
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDate = userDefaults.object(forKey: lastDateKey) as? Date,
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            // 既に本日処理している場合は何もしない
            return
        }
        // １日経過しているので、クーポンを追加
        var count = additional
        let preferentialMode = UserDefaults.standard.bool(forKey: AppCom.USER_DEFKEY_SPECIAL_USER)
        if preferentialMode {
            // 特別ユーザの場合は、MAXまで追加
            count = CouponDB.MAX - getCount()
        }
        add(count)
        userDefaults.set(today, forKey: lastDateKey)
        
    }
    
}
