//
//  UIResponder+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// UIResponderを拡張
extension UIResponder {
    
    func findViewController<T: UIViewController>() -> T? {
        var responder = self.next
        while responder != nil {
            if let viewController = responder as? T {
                return viewController
            }
            responder = responder!.next
        }
        return nil
    }
    
}
