//
//  UIButton+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// UIButtonを拡張
extension UIButton {
    
    // イメージ設定 with カラー
    func setImage(named: String, assetColor: String) {
        setImage(UIImage(named: named)?.withRenderingMode(.alwaysTemplate), for: .normal)
        tintColor = UIColor.asset(named: assetColor)
    }
    func setImage(named: String, color: UIColor, size: CGSize? = nil) {
        var image = UIImage(named: named)
        if let size = size {
            image = image?.resize(size).withRenderingMode(.alwaysTemplate)
        }
        setImage(image, for: .normal)
        tintColor = color
    }
    
}
