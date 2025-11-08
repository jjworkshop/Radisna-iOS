//
//  CommnLayer.swift
//  CALayerのサブクラス（共通部分のインプリメント）
//
//  Created by Mitsuhiro Shirai on 2018/07/05.
//  Copyright © 2018年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit

class CommnLayer: CALayer {
    
    public let fontS = UIFont.systemFont(ofSize: 12.0)
    public let fontM = UIFont.systemFont(ofSize: 15.0)
    public let fontL = UIFont.systemFont(ofSize: 18.0)

    open var attr_M_center_label: [NSAttributedString.Key: Any]!

    override init() {
        super.init()
        self.contentsScale = UIScreen.main.scale
    
        // 利用する文字列関連のオブジェクト
        let paragraphStyleCenter = NSMutableParagraphStyle()
        paragraphStyleCenter.alignment = .center
        attr_M_center_label = [
            NSAttributedString.Key.paragraphStyle: paragraphStyleCenter,
            NSAttributedString.Key.font: fontM,
        ]
}
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(in ctx: CGContext) {
        
        UIGraphicsPushContext(ctx)
        ctx.setShouldAntialias(true)
        drawContents(ctx)
        UIGraphicsPopContext()
    }
    
    func drawContents(_ ctx: CGContext) {
        // オーバーライド
    }
    
    // 角丸四角の作画
    open func drawRoundRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat) {
        ctx.move(to: CGPoint(x: rect.minX, y: rect.midY))
        ctx.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.midX, y: rect.minY), radius: radius)
        ctx.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.midY), radius: radius)
        ctx.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.midX, y: rect.maxY), radius: radius)
        ctx.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.midY), radius: radius)
        ctx.closePath()
        ctx.fillPath()
    }
    
}
