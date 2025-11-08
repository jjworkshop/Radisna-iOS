//
//  FloatingBtnView.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//  Copyright © 2018年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit

class FloatingBtnView: UIView {

    internal var isFirst = true
    let button = UIButton()
    private let bgView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    private func setup() {
        self.backgroundColor = UIColor.clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if (!isFirst) {return}    // 最初だけ
        isFirst = false
        // レイアウト確定後の最初の処理
        let round = min(self.bounds.width, self.bounds.height) / 2
        self.layer.cornerRadius = round
        self.clipsToBounds = true
        self.layer.borderWidth = 2.0
        self.layer.borderColor = UIColor.white.cgColor
        bgView.frame = self.bounds
        bgView.layer.cornerRadius = round
        bgView.clipsToBounds = true
        bgView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        button.frame = self.bounds
        button.setTitle(nil, for: .normal)
        addSubview(bgView)
        addSubview(button)
    }

    func setImage(name: String, size: CGFloat, color: UIColor = UIColor.white, alpha: CGFloat = 0.8) {
        let img = UIImage(named: name)?.resize(CGSize(width: size, height: size)).withRenderingMode(.alwaysTemplate)
        button.setImage(img, for: .normal)
        button.tintColor = color
        button.alpha = alpha
    }
    
    func changeButton(color: UIColor, alpha: CGFloat = 0.8) {
        button.tintColor = color
        button.alpha = alpha
    }
    
    func fadeIn() {
        self.alpha = 1.0
        UIView.animate(withDuration: 1.0, delay: 1.5, options: [.curveEaseIn, .curveEaseOut, .allowUserInteraction], animations: {
            self.alpha = 0.3
        }) { _ in }
    }
}
