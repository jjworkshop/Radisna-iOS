//
//  String+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// Stringを拡張
extension String {
    
    // 文字列ー＞Intに変換
    func toInt() -> Int {
        if (self.isNumeric()) {
            return Int(self)!
        }
        return 0
    }
    
    // 文字列ー＞Doubleに変換
    func toDouble() -> Double {
        if let d = Double(self) {
            return Double(d)
        }
        return 0.0
    }
    
    // 16進文字列ー＞をUInt32に変換
    func toUint32fromHex() -> UInt32 {
        if let hex = UInt32(self, radix: 16) {
            return hex
        }
        return 0
    }
    
    // 数値チェック
    func isNumeric() -> Bool{
        return (self =~ "(^$)|(^\\d*$)")
    }
    
    // 数値チェック（桁数指定）
    func isNumeric(length: Int) -> Bool {
        return (self =~ "(^$)|(^\\d{\(length)}$)")
    }
    
    // URLエンコード
    var urlEncoded: String {
        // 半角英数字 + "/?-._~" のキャラクタセットを定義
        let charset = CharacterSet.alphanumerics.union(.init(charactersIn: "/?-._~"))
        // 一度すべてのパーセントエンコードを除去(URLデコード)
        let removed = removingPercentEncoding ?? self
        // あらためてパーセントエンコードして返す
        return removed.addingPercentEncoding(withAllowedCharacters: charset) ?? removed
    }
    
    // URLとして有効かどうかチェック
    func isUrl() -> Bool {
        return (self =~ "^(https?|ftp)(:\\/\\/[-_.!~*\\'()a-zA-Z0-9;\\/?:\\@&=+\\$,%#]+)$")
    }
    
    func isEmail() -> Bool {
        return (self =~ "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}$")
    }
    
    // 電話番頭として有効かどうかチェック
    func isTelNo() -> Bool {
        return (self =~ "^\\d{2,4}-\\d{1,4}-\\d{4}$")
    }
    
    // 日付として有効かどうか簡易チェック（yyyy/m/d）
    func isDate() -> Bool {
        return (self =~ "^\\d{4}/\\d{1,2}/\\d{1,2}$")
    }
    
    // 時間として有効かどうかチェック（h:m:s）
    func isTime() -> Bool {
        return (self =~ "^\\d{1,2}:\\d{1,2}:\\d{1,2}$")
    }
    
    // 左から文字埋めする
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return String(self.suffix(toLength))
        }
    }
}


extension Optional where Wrapped == String {
    // nil or Empty を判定
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}


