//
//  UIColor+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// UIColorを拡張
extension UIColor {
    
    // カラー指定をRGB+Alpha値で設定する（Alphaは省略可能）
    class func hexx(rgb: UInt32, alpha: CGFloat = 1.0) -> UIColor{
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return UIColor(red:r,green:g,blue:b,alpha:alpha)
    }
        
    // カラー指定をAssetで設定する（Alphaは省略可能）
    class func asset(named: String) -> UIColor{
        return UIColor(named: named)!
    }
    
    // カラー１６新文字列で取得
    func toHexString() -> String {
        var red: CGFloat     = 1.0
        var green: CGFloat   = 1.0
        var blue: CGFloat    = 1.0
        var alpha: CGFloat    = 1.0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let r = Int(String(Int(floor(red*100)/100 * 255)).replacingOccurrences(of: "-", with: ""))!
        let g = Int(String(Int(floor(green*100)/100 * 255)).replacingOccurrences(of: "-", with: ""))!
        let b = Int(String(Int(floor(blue*100)/100 * 255)).replacingOccurrences(of: "-", with: ""))!
        let result = String(r, radix: 16).leftPadding(toLength: 2, withPad: "0") + String(g, radix: 16).leftPadding(toLength: 2, withPad: "0") + String(b, radix: 16).leftPadding(toLength: 2, withPad: "0")
        return result
    }
    
    // 輝度取得：暗い色は、0.0 に近い値になり、明るい色は、1.0 に近い値
    // by https://software.small-desk.com/development/2021/01/30/swiftui-light-dark-color-judge/
    func luminance() -> Double {
        var red: CGFloat     = 1.0
        var green: CGFloat   = 1.0
        var blue: CGFloat    = 1.0
        var alpha: CGFloat    = 1.0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = (red * 0.299 + green * 0.587 + blue * 0.114)
        return luminance
    }
    
    // ダイナミックカラー対応
    public class func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13, *) {
            return UIColor { (traitCollection) -> UIColor in
                if traitCollection.userInterfaceStyle == .dark {
                    return dark
                }
                else {
                    return light
                }
            }
        }
        return light
    }
    
    // テキストカラー
    public static var DynamicTextColor: UIColor {
        return dynamicColor(
            light: .black,
            dark:  .white
        )
    }
    
}
