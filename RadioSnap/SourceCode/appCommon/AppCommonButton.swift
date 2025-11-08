//
//  AppCommonButton.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//  Copyright © 2020 Mitsuhiro Shirai. All rights reserved.
//

import UIKit

class AppCommonButton: UIButton {

    func customSetup(configuration: UIButton.Configuration? = nil) {
        self.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        self.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15.0)
        self.setTitleColor(UIColor.white, for: .normal)
        self.setTitleColor(UIColor.asset(named: AppCom.rgb_text_disable), for: .disabled)
        self.layer.borderWidth = 1.5
        self.layer.borderColor = UIColor.white.cgColor
        self.layer.cornerRadius = self.bounds.size.height / 2
        if configuration != nil {
            self.configuration = configuration
        }
    }

}
