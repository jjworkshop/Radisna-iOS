//
//  UIView+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// UIViewを拡張
extension UIView {
    
    // 親viewにfitさせる
    func fitParentView(selectedView:UIView) {
        selectedView.translatesAutoresizingMaskIntoConstraints = false
        let views = ["subview" : selectedView]
        self.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "V:|[subview]|",
                options: NSLayoutConstraint.FormatOptions(rawValue: 0),
                metrics: nil,
                views: views
            )
        )
        self.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "H:|[subview]|",
                options: NSLayoutConstraint.FormatOptions(rawValue: 0),
                metrics: nil,
                views: views
            )
        )
    }
    
    // タグIDからサブビューを探す
    func find(tag: Int) -> UIView? {
        return self.viewWithTag(tag)
    }
        
    // ブラーを追加
    func addBlur(style: UIBlurEffect.Style = .dark) {
        let blurView = UIVisualEffectView()
        blurView.effect = UIBlurEffect(style: style)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .clear
        insertSubview(blurView, at: 0)
    }
    
}
