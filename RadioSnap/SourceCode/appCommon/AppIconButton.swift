//
//  AppIconButton.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//

import UIKit

class AppIconButton: UIButton {

    func customSetup(iconNamed: String, iconSize: CGSize) {
        let images = UIImage(named: iconNamed)?.withRenderingMode(.alwaysTemplate).resize(iconSize)
        self.setImage(images?.withTintColor(UIColor.label), for: .normal)
        self.setImage(images?.withTintColor(UIColor.systemGray), for: .highlighted)
        self.setImage(images?.withTintColor(UIColor.asset(named: AppCom.rgb_text_disable)), for: .disabled)
        self.imageView?.contentMode = .scaleAspectFit
    }

}
