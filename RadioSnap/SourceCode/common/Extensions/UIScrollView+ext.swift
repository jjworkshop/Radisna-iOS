//
//  UIScrollView+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// UIScrollViewを拡張
extension UIScrollView {
    
    public enum ScrollDirection {
        case top
        case bottom
        case left
        case right
    }
    
    // それぞれの位置に移動
    public func scroll(to direction: ScrollDirection, animated: Bool) {
        let offset: CGPoint
        switch direction {
        case .top:
            offset = CGPoint(x: contentOffset.x, y: -contentInset.top)
        case .bottom:
            offset = CGPoint(x: contentOffset.x, y: max(-contentInset.top, contentSize.height - frame.height + contentInset.bottom))
        case .left:
            offset = CGPoint(x: -contentInset.left, y: contentOffset.y)
        case .right:
            offset = CGPoint(x: max(-contentInset.left, contentSize.width - frame.width + contentInset.right), y: contentOffset.y)
        }
        setContentOffset(offset, animated: animated)
    }
    
    // 指定した位置（左上）に移動　オーバースクロールを防止
    public func scroll(to pos: CGPoint, animated: Bool) {
        let offset = CGPoint(x: min(max(-contentInset.left, contentSize.width - frame.width + contentInset.right),  pos.x),
                             y: min(max(-contentInset.top, contentSize.height - frame.height + contentInset.bottom), pos.y))
        setContentOffset(offset, animated: animated)
    }
    
}
