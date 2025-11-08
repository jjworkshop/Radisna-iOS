//
//  CommonView.swift
//  UIViewのサブクラス（共通部分のインプリメント）
//
//  Created by Mitsuhiro Shirai on 2019/03/04.
//  Copyright © 2018年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit
import RxSwift

/*
 ViewControllerのトップViewで共通化する部分をサブクラス化してインプリメントしておく 
 */

class CommonView: UIView {

    internal var isFirstLayout = true
    let indicator = UIActivityIndicatorView(style: .large)
    private var indicatorCounter = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if (!isFirstLayout) {return}    // 最初だけ
        isFirstLayout = false
        
        // レイアウト確定後の最初の処理
        firstlayoutSubviews()
        
        // インジケーター
        indicator.color = UIColor.systemOrange
        indicator.center = CGPoint(x: self.center.x, y: self.bounds.size.height / 2)
        self.addSubview(indicator)        
    }

    // サブクラスでオーバーライドする（ super.setup() を忘れずに！！）
    open func setup() {}

    // サブクラスでオーバーライドする
    open func firstlayoutSubviews() {}

    // インジケーター（ActivityIndicator）の表示管理
    // どの画面でもクルクルインジケーターが必要なときに利用できるようにしている
    func showIndicator() {
        if (indicatorCounter == 0) {
            indicator.startAnimating()
        }
        indicatorCounter += 1
    }
    func hideIndicator() {
        indicatorCounter -= 1
        if (indicatorCounter <= 0) {
            indicatorCounter = 0
            indicator.stopAnimating()
        }
    }
    func forceIndicatorToHide() {
        // 強制停止
        indicator.stopAnimating()
        indicatorCounter = 0
    }
}
