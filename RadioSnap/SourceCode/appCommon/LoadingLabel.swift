//
//  LoadingLabel.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//  Copyright © 2020 Mitsuhiro Shirai. All rights reserved.
//

import UIKit

class LoadingLabel: UILabel {

    internal var isFirstLayout = true
    let loadingText = "　Contents Loading...　"
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if (!isFirstLayout) {return}    // 最初だけ
        isFirstLayout = false
        layer.cornerRadius = 8
        clipsToBounds = true
        showLoading()
    }
    
    func showLoading() {
        backgroundColor = UIColor.systemOrange
        textColor = UIColor.white
        font = UIFont.systemFont(ofSize: 16.0)
        text = loadingText
        isHidden = false
    }

}
