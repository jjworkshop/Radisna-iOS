//
//  UISearchBar+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// UISearchBarを拡張
extension UISearchBar {
    
    // ブラーを無効にする
    func disableBlur() {
        backgroundImage = UIImage()
        isTranslucent = true
    }
    
    // テキストフィールドの取得
    var textField: UITextField? {
        return value(forKey: "_searchField") as? UITextField
    }
    
}
