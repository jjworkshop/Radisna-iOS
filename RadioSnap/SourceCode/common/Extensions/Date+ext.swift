//
//  Date+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// Date を拡張
extension Date {
    
    // 共通カレンダー
    var calendar: Calendar {
        return Calendar(identifier: .gregorian)
    }
    
    // 現在の日時に対して「年月日時分秒」をコンポーネント単位で絶対値を指定（部分指定可能で、新しいDateを戻す）
    func fixed(year: Int? = nil, month: Int? = nil, day: Int? = nil, hour: Int? = nil, minute: Int? = nil, second: Int? = nil) -> Date {
        let calendar = self.calendar
        var comp = DateComponents()
        comp.year   = year   ?? calendar.component(.year,   from: self)
        comp.month  = month  ?? calendar.component(.month,  from: self)
        comp.day    = day    ?? calendar.component(.day,    from: self)
        comp.hour   = hour   ?? calendar.component(.hour,   from: self)
        comp.minute = minute ?? calendar.component(.minute, from: self)
        comp.second = second ?? calendar.component(.second, from: self)
        return calendar.date(from: comp)!
    }
    
    // こちらは相対値で指定（他 fixed と同じ：マイナスも可）
    func added(year: Int? = nil, month: Int? = nil, day: Int? = nil, hour: Int? = nil, minute: Int? = nil, second: Int? = nil) -> Date {
        let calendar = self.calendar
        var comp = DateComponents()
        comp.year   = (year   ?? 0) + calendar.component(.year,   from: self)
        comp.month  = (month  ?? 0) + calendar.component(.month,  from: self)
        comp.day    = (day    ?? 0) + calendar.component(.day,    from: self)
        comp.hour   = (hour   ?? 0) + calendar.component(.hour,   from: self)
        comp.minute = (minute ?? 0) + calendar.component(.minute, from: self)
        comp.second = (second ?? 0) + calendar.component(.second, from: self)
        return calendar.date(from: comp)!
    }
    
    // 年月日を指定してのイニシャライザー（時分秒は０に設定）
    init(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        self.init(
            timeIntervalSince1970: Date().fixed(
                year:   year,
                month:  month,
                day:    day,
                hour:   0,
                minute: 0,
                second: 0
                ).timeIntervalSince1970
        )
    }

    // 年月日時間（秒以外）を指定してのイニシャライザー（秒は０に設定）
    init(year: Int? = nil, month: Int? = nil, day: Int? = nil, HH: Int? = nil, MM: Int? = nil) {
        self.init(
            timeIntervalSince1970: Date().fixed(
                year:   year,
                month:  month,
                day:    day,
                hour:   HH,
                minute: MM,
                second: 0
                ).timeIntervalSince1970
        )
    }

    // 本日の日付で時を設定したイニシャライザー（分秒は０に設定）
    init(hour: Int) {
        self.init(
            timeIntervalSince1970: Date().fixed(
                year:   nil,
                month:  nil,
                day:    nil,
                hour:   hour,
                minute: 0,
                second: 0
                ).timeIntervalSince1970
        )
    }
    
    // 文字列と文字列のフォーマットから
    init(string: String, format: String) {
        let formatter: DateFormatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        if let dt = formatter.date(from: string) {
            self.init(timeIntervalSince1970: dt.timeIntervalSince1970)
        }
        else {
            // エラー
            assert(false)
            self.init()
        }
    }
        
    // 年月日時分秒を個別に取得
    var year: Int {
        return calendar.component(.year, from: self)
    }
    var month: Int {
        return calendar.component(.month, from: self)
    }
    var day: Int {
        return calendar.component(.day, from: self)
    }
    var hour: Int {
        return calendar.component(.hour, from: self)
    }
    var minute: Int {
        return calendar.component(.minute, from: self)
    }
    var second: Int {
        return calendar.component(.second, from: self)
    }
    var weekday: Int {
        return calendar.component(.weekday, from: self)
    }
    
    // 曜日の取得
    var weekNameJ: String {
        let index = calendar.component(.weekday, from: self) - 1 // index値を 1〜7 から 0〜6 にしている
        return ["日", "月", "火", "水", "木", "金", "土"][index]
    }
    var weekNameE: String {
        let index = calendar.component(.weekday, from: self) - 1 // index値を 1〜7 から 0〜6 にしている
        return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][index]
    }
    
    // 日付のみ同じかチェック
    func isSameDate(_ date: Date) -> Bool {
        return (self.year == date.year && self.month == date.month && self.day == date.day)
    }
    
    // 日付の差分を取得
    func dayInterval(_ date: Date) -> Int? {
        let calendar = self.calendar
        return (calendar.dateComponents([.day], from: self, to: date)).day
    }
    
    // 分の差分を取得（引数の方を大きい日付にするとプラス値となる）
    func minuteInterval(_ date: Date) -> Int? {
        let calendar = self.calendar
        return (calendar.dateComponents([.minute], from: self, to: date)).minute
    }

}
